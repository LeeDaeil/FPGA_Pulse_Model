import sys
import socket
import struct
from PyQt5.QtWidgets import *
from PyQt5.QtGui import *
from PyQt5.QtCore import *

from pyqtgraph.graphicsItems.GridItem import GridItem
from pyqtgraph import LabelItem
import pyqtgraph as pg
import math
import numpy as np
import time
import random

VAULT_SIZE  = 40    # 볼트 크기
PLOT_SKIP   = 0     # 그래프 x 포인트 스킵용
DIRECT_SEND_CPS = True  # True: CPS를 직접 전송, False: CPS를 청크로 변환하여 전송
MODE = 2    # 0: Neutron,   1: Gamma,    2: Neutron+Gamma


class CustomPushButton(QPushButton):
    def __init__(self, text):
        super().__init__(text)
        self.setFont(QFont("Arial", 16, QFont.Bold))

    def paintEvent(self, event):
        painter = QPainter(self)
        rect = self.rect()

        # 눌림 여부에 따라 색 반전
        if self.isDown():
            light = QColor(0, 0, 0)
            dark = QColor(255, 255, 255)
        else:
            light = QColor(255, 255, 255)
            dark = QColor(0, 0, 0)

        # 두께
        edge = 4

        # 왼쪽 윗 삼각형 (Light)
        light_poly = QPolygon([
            QPoint(0, rect.height()),
            QPoint(0, 0),
            QPoint(rect.width(), 0),
            QPoint(rect.width() - edge, edge),
            QPoint(edge, edge),
            QPoint(edge, rect.height() - edge)
        ])
        painter.setBrush(light)
        painter.setPen(light)
        painter.drawPolygon(light_poly)

        # 오른쪽 아래 삼각형 (Dark)
        dark_poly = QPolygon([
            QPoint(rect.width(), 0),
            QPoint(rect.width(), rect.height()),
            QPoint(0, rect.height()),
            QPoint(edge, rect.height() - edge),
            QPoint(rect.width() - edge, rect.height() - edge),
            QPoint(rect.width() - edge, edge)
        ])
        painter.setBrush(dark)
        painter.setPen(dark)
        painter.drawPolygon(dark_poly)

        # 텍스트 그리기
        painter.setPen(Qt.black)
        painter.setFont(self.font())
        painter.drawText(rect, Qt.AlignCenter, self.text())

class StartStopButton(CustomPushButton):
    def __init__(self, text):
        super().__init__(text)
        self.setFixedSize(100, 100)
        self.state = False  # 초기 상태는 시작 상태
        self.netstate = False  # 초기 네트워크 상태
        
    def set_state(self, state, netstate):
        self.netstate = netstate
        self.state = state
        self.update()  # 상태 변경 시 버튼 업데이트

    def paintEvent(self, event):
        painter = QPainter(self)
        # 배경 색상 채우기
        if self.state:
            if self.text() == "START":
                if self.netstate:
                    painter.fillRect(self.rect(), QColor(213, 0, 0))
                else:
                    painter.fillRect(self.rect(), QColor(255, 197, 5))
            else:
                painter.fillRect(self.rect(), QColor(57, 194, 144))
        else:
            painter.fillRect(self.rect(), QColor(204, 204, 204))
        
        super().paintEvent(event)

class UpDownButton(CustomPushButton):
    def __init__(self, direction):
        super().__init__('')
        self.w = 120 # 너비
        self.h = 100 # 높이
        self.tm = 20 # 삼각형 마진
        self.scaled_triangle_y = 0.8 # 삼각형 높이 비율
        self.setFixedSize(self.w, self.h)
        if direction == 'up':
            self.orgin_triangle_shape = [QPoint(int(self.w/2), self.tm), QPoint(self.w - self.tm, self.h - self.tm), QPoint(self.tm, self.h - self.tm)]
        elif direction == 'down': 
            self.orgin_triangle_shape = [QPoint(self.tm, self.tm), QPoint(self.w - self.tm, self.tm), QPoint(int(self.w/2), self.h - self.tm)]
        self.direction = direction  # 'up' 또는 'down'으로 방향 설정

    def paintEvent(self, event):
        painter = QPainter(self)
        # 삼각형 그리기
        painter.setBrush(QColor(0, 0, 0))
        painter.setPen(Qt.NoPen)
        # 삼각형 높이 조정
        center_y = self.h / 2
        
        # Y축만 축소한 포인트 계산
        points = [
            QPoint(p.x(), int(center_y + (p.y() - center_y) * self.scaled_triangle_y))
            for p in self.orgin_triangle_shape
        ]

        painter.drawPolygon(QPolygon(points))
        super().paintEvent(event)

class CustomGrid(GridItem):
    def __init__(self, spacing=10):
        super().__init__()
        self.spacing = spacing
        self.pen = QPen()
        self.pen.setColor(QColor(134, 128, 116))
        self.pen.setStyle(Qt.PenStyle.DotLine)
        self.pen.setCosmetic(True)
        self.pen.setWidth(1)

    def paint(self, painter, *args):
        if self.getViewBox() is None:
            return

        painter.setPen(self.pen)
        rect = self.boundingRect()
        x0, y0 = rect.left(), rect.top()
        x1, y1 = rect.right(), rect.bottom()

        # 현재 view 범위 받아오기
        x_range, y_range = self.getViewBox().viewRange()

        # 축 길이에 따라 적당한 간격 계산 (self.spacing개 정도로 나누기)
        x_span = x_range[1] - x_range[0]
        y_span = y_range[1] - y_range[0]
        x_spacing = self._nice_tick(x_span / self.spacing)
        y_spacing = self._nice_tick(y_span / self.spacing)

        # 수직선
        x = x0 - (x0 % x_spacing)
        while x <= x1:
            painter.drawLine(QLineF(x, y0, x, y1))
            x += x_spacing

        # 수평선
        y = y0 - (y0 % y_spacing)
        while y <= y1:
            painter.drawLine(QLineF(x0, y, x1, y))
            y += y_spacing

    def _nice_tick(self, raw_step):
        """'간격을 반환 (1, 2, 5 단위)"""
        exp = math.floor(math.log10(raw_step))
        base = raw_step / (10 ** exp)
        if base < 1.5:
            nice = 1
        elif base < 3.5:
            nice = 2
        elif base < 7.5:
            nice = 5
        else:
            nice = 10
        return nice * (10 ** exp)

class TCPClient(QThread):
    received = pyqtSignal(str)
    data_received = pyqtSignal(bytes)
    server_state = pyqtSignal(bool)
    
    def __init__(self):
        super().__init__()
        self.host = '192.168.1.10'   # 보드 IP 주소로 변경
        self.port = 7                # 보드 포트
        self.client_socket = None
        self.running = True
        self.tcp_run = False
        self.prev_val = "0"
        self.pulse_time_chunk_block = []
        
    def run(self):
        try:
            if self.client_socket is None:
                self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.client_socket.connect((self.host, self.port))
            
                # 연결 상태 신호 전송
                self.server_state.emit(True)
                print(f"Connected to {self.host}:{self.port}")
            while self.running:
                if self.tcp_run:
                    start_time = time.time()
                    
                    if DIRECT_SEND_CPS:
                        # TEST 모드: 인터페이스에 표기된 CPS 값을 그대로 전송
                        cps = self.prev_val
                    else:
                        # 1. Read pulse pos data to cps
                        if len(self.pulse_time_chunk_block) == 0:
                            if self.prev_val == "0":
                                cps = 0
                            else:
                                # 펄스 신호 대기열 모두 소진 시 대기열 재생성
                                self.pulse_time_chunk_block = self.cps_to_pulse_time_block(self.prev_val)
                                # print('Recreating pulse time chunk block...')
                                # 펄스 신호 대기열에서 하나씩 꺼내서 전송
                                cps = self.pulse_time_chunk_block.pop(0)
                        else:
                            # 펄스 신호 대기열에서 하나씩 꺼내서 전송
                            cps = self.pulse_time_chunk_block.pop(0)
                            
                    if not DIRECT_SEND_CPS:
                        cps1 = int(cps/2)
                        cps2 = int(cps/2) if cps % 2 == 0 else int(cps/2) + 1
                    else:
                        cps1, cps2 = cps, cps

                    # 2. Send cps
                    if MODE == 0: # Neutron
                        self.client_socket.sendall(f'{cps1},{cps2},{0},{0}'.encode())
                    elif MODE == 1:  # Gamma
                        self.client_socket.sendall(f'{0},{0},{cps1},{cps2}'.encode())
                    elif MODE == 2:  # Neutron+Gamma
                        self.client_socket.sendall(f'{cps1},{cps2},{cps1},{cps2}'.encode())

                    data = self.client_socket.recv(8192)
                    
                    # print(f"One command sent: {cps1}, {cps2}, Time taken: {time.time() - start_time:.6f} seconds")
                    
                    time.sleep(0.01)  # 1초 간격으로 명령 전송 ! 그래프 업데이트 하는 시간 고려해야함.
                    
                    if data:
                        # print(f"Data Len : {len(data)}")
                        self.data_received.emit(data)
                    else:
                        print("No data received, closing connection.")
                else:
                    pass
        except Exception as e:
            self.received.emit(f"Connection error: {e}")
            self.server_state.emit(False)
    
    def send_message(self, cps:str):
        # 인터페이스에서 CPS 값 받으면, pulse_time_bloack 대기열 생성 및 대체
        #    - 1개 청크는 2048개 포인트를 가지고 각 포인트는 20 ns 의미한다.
        #      따라서, 1개 청크가 표현하는 시간 윈도우는 40.56 us 의미한다.
        #    - 1개 청크는 최소 1개 펄스를 만들 수 있다.
        #      1 cps 를 표현하기 위해서는 약 24,659개의 청크가 필요하다.
        self.prev_val = cps
        if self.prev_val != "0":
            self.pulse_time_chunk_block = self.cps_to_pulse_time_block(cps)
        else:
            self.pulse_time_chunk_block = []
        
    def cps_to_pulse_time_block(self, cps: str, slots_per_chunk=2028, time_per_slot_ns=20):
        x_cps = int(cps)
        chunk_time_sec = (slots_per_chunk * time_per_slot_ns) * 1e-9
        nub_chunk = int(1 / chunk_time_sec)
        print(f"cps: {x_cps}, chunk_time_sec: {chunk_time_sec}, nub_chunk: {nub_chunk}")
        if 1e+6 < x_cps:
            divided_chunk = int(nub_chunk/1000)
            # 1. 초기화
            list_chunk = np.zeros(divided_chunk, dtype=int)
            # 2. 요청 x_cps개를 랜덤한 인덱스에 분포시키기
            idxs = np.random.randint(0, divided_chunk, size=int(x_cps/1000))
            # 3. 각 인덱스의 출현 횟수를 카운트해서 누적
            np.add.at(list_chunk, idxs, 1)
        else:
            # 1. 초기화
            list_chunk = np.zeros(nub_chunk, dtype=int)
            # 2. 요청 x_cps개를 랜덤한 인덱스에 분포시키기
            idxs = np.random.randint(0, nub_chunk, size=x_cps)
            # 3. 각 인덱스의 출현 횟수를 카운트해서 누적
            np.add.at(list_chunk, idxs, 1)
        
        return list_chunk.tolist()
        
    def calculate_chunks_for_xcps(x_cps, slots_per_chunk=2028, time_per_slot_ns=20):
        # 청크 시간 (초 단위)
        chunk_time_sec = (slots_per_chunk * time_per_slot_ns) * 1e-9
        # 펄스 하나 당 청크 수
        chunks_needed = 1 / (x_cps * chunk_time_sec)
        return int(chunks_needed)

    def change_tcp_model_run(self, state):
        self.tcp_run = state

    def stop(self):
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        self.quit()
    
class MainWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.setGeometry(200, 200, 1, 1)
        self.initUI()
        
        self.sim_state = False  # 시뮬레이션 상태 초기화
        self.net_state = False  # 네트워크 상태 초기화
        
        self.client_thread = None

    def initUI(self):
        # 창 크기 설정
        #self.setGeometry(300, 300, 725, 525)
        self.setWindowTitle("Signal Generator")

        # 배경 색상 설정 (RGB 168, 168, 168)
        palette = QPalette()
        palette.setColor(QPalette.Window, QColor(168, 168, 168))
        self.setAutoFillBackground(True)
        self.setPalette(palette)

        # Main 레이아웃 설정
        main_layout = QHBoxLayout()
        self.setLayout(main_layout)
        
        # 왼쪽 패널 레이아웃 설정
        left_panel_widget = QWidget()
        # left_panel_widget.setFixedSize(725, 525)
        left_panel_widget.setMinimumSize(725, 525)
        left_panel = QVBoxLayout()
        left_panel.setContentsMargins(0, 0, 0, 0)
        left_panel.setSpacing(0)
        left_panel_widget.setLayout(left_panel)

        # 오른쪽 패널 레이아웃 설정
        right_panel_widget = QWidget()
        # right_panel_widget.setFixedSize(725, 525)
        right_panel_widget.setMinimumSize(725, 525)
        right_panel = QVBoxLayout()
        right_panel.setContentsMargins(0, 0, 0, 0)
        right_panel.setSpacing(0)
        right_panel_widget.setLayout(right_panel)
        
        # 왼쪽 / 오른쪽 패널 움직이는 경계선 설정
        splitter = QSplitter(Qt.Horizontal)
        splitter.setHandleWidth(5)
        splitter.setStyleSheet("QSplitter::handle { background-color: rgb(0, 0, 0); }")
        splitter.addWidget(left_panel_widget)  # 왼쪽 패널을 위한 빈 위젯
        splitter.addWidget(right_panel_widget)  # 오른쪽 패널을 위한 빈 위젯
        main_layout.addWidget(splitter)
    
        if True: # 왼쪽 패널
            # 왼쪽 패널 상단 볼트 체결 부분
            left_panel.addLayout(self.add_nut_layout())
        
            # 패널 내부 레이아웃 설정
            panel_hbox = QHBoxLayout()
            panel_in_vbox = QVBoxLayout()
            
            panel_hbox.setContentsMargins(40, 0, 40, 0)
            left_panel.addLayout(panel_hbox)
            panel_hbox.addLayout(panel_in_vbox)
        
            # 패널 내부 레이아웃에 위젯 추가 시작 --------------------------------------------------------
            # 1. 패널 상단 제목 추가
            title_label = QLabel("Signal Generator", self)
            title_label.setAlignment(Qt.AlignCenter)
            title_label.setFont(QFont("Arial", 16, QFont.Bold))
            title_label.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            panel_in_vbox.addWidget(title_label)
            # 2. 패널 내부 Spacer 추가
            panel_in_vbox.addStretch(1)
            # 3. 패널 내부 현재 CPS 상태 표시
            current_cps_layout = QHBoxLayout()
            current_cps_layout.setContentsMargins(20, 0, 20, 0)
            current_cps_layout.setSpacing(20)
            ## 3.1 현재 CPS 상태 표시 레이블
            current_cps_label = QLabel("Current")
            current_cps_label.setAlignment(Qt.AlignCenter)
            current_cps_label.setFont(QFont("Arial", 16, QFont.Bold))
            current_cps_label.setStyleSheet("color: black;")
            current_cps_label.setFixedWidth(100)  # 고정 너비 설정
            current_cps_layout.addWidget(current_cps_label)
            ## 3.2 현재 CPS 값 표시 레이블
            self.current_cps_value = QLabel("0")
            self.current_cps_value.setAlignment(Qt.AlignCenter)
            self.current_cps_value.setFont(QFont("Arial", 16, QFont.Bold))
            self.current_cps_value.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            # self.current_cps_value.setFixedWidth(xxx) # 너비 유동적
            current_cps_layout.addWidget(self.current_cps_value)
            ## 3.2 현재 CPS 10^x 표시 레이블
            self.current_cps_exp_value = QLabel("0.00 x 10^0")
            self.current_cps_exp_value.setAlignment(Qt.AlignCenter)
            self.current_cps_exp_value.setFont(QFont("Arial", 16, QFont.Bold))
            self.current_cps_exp_value.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            self.current_cps_exp_value.setFixedWidth(150) # 고정 너비 설정 
            current_cps_layout.addWidget(self.current_cps_exp_value)
            ## 3.3 CPS 단위 표시 레이블
            current_cps_unit_label = QLabel("CPS")
            current_cps_unit_label.setAlignment(Qt.AlignLeft|Qt.AlignVCenter)
            current_cps_unit_label.setFont(QFont("Arial", 16, QFont.Bold))
            current_cps_unit_label.setStyleSheet("color: black;")
            current_cps_unit_label.setFixedWidth(50)  # 고정 너비 설정
            current_cps_layout.addWidget(current_cps_unit_label)
            panel_in_vbox.addLayout(current_cps_layout)
            panel_in_vbox.addStretch(1)
            # 4. 패널 내부 타겟 CPS 상태 표시
            target_cps_layout = QHBoxLayout()
            target_cps_layout.setContentsMargins(20, 0, 20, 0)
            target_cps_layout.setSpacing(20)
            ## 4.1 타겟 CPS 상태 표시 레이블
            target_cps_label = QLabel("Target")
            target_cps_label.setAlignment(Qt.AlignCenter)
            target_cps_label.setFont(QFont("Arial", 16, QFont.Bold))
            target_cps_label.setStyleSheet("color: black;")
            target_cps_label.setFixedWidth(100)  # 고정 너비 설정
            target_cps_layout.addWidget(target_cps_label)
            ## 4.2 타겟 CPS 값 표시 레이블
            self.target_cps_value = QLabel("0")
            self.target_cps_value.setAlignment(Qt.AlignCenter)
            self.target_cps_value.setFont(QFont("Arial", 16, QFont.Bold))
            self.target_cps_value.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            # self.target_cps_value.setFixedWidth(xxx) # 너비 유동적
            target_cps_layout.addWidget(self.target_cps_value)
            ## 4.2 타겟 CPS 10^x 표시 레이블
            self.target_cps_exp_value = QLabel("0.00 x 10^0")
            self.target_cps_exp_value.setAlignment(Qt.AlignCenter)
            self.target_cps_exp_value.setFont(QFont("Arial", 16, QFont.Bold))
            self.target_cps_exp_value.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            self.target_cps_exp_value.setFixedWidth(150) # 고정 너비 설정
            target_cps_layout.addWidget(self.target_cps_exp_value)
            ## 4.3 CPS 단위 표시 레이블
            target_cps_unit_label = QLabel("CPS")
            target_cps_unit_label.setAlignment(Qt.AlignLeft|Qt.AlignVCenter)
            target_cps_unit_label.setFont(QFont("Arial", 16, QFont.Bold))
            target_cps_unit_label.setStyleSheet("color: black;")
            target_cps_unit_label.setFixedWidth(50)  # 고정 너비 설정
            target_cps_layout.addWidget(target_cps_unit_label)
            panel_in_vbox.addLayout(target_cps_layout)
            # 5. 패널 내부 Spacer 추가
            panel_in_vbox.addStretch(1)
            # 6. 패널 내부 버튼 레이아웃 (START / STOP / 숫자 키패드 / 방향키 / CONFIRM / CLEAR)
            button_layout = QHBoxLayout()
            button_layout.setContentsMargins(20, 0, 20, 0)
            button_layout.setSpacing(20)
            panel_in_vbox.addLayout(button_layout)
            # 6.1 START / STOP 버튼
            start_stop_layout = QVBoxLayout()
            self.start_btn = StartStopButton("START")
            self.start_btn.set_state(False, False)
            self.start_btn.clicked.connect(lambda: self.start_stop_action("START"))
            self.stop_btn = StartStopButton("STOP")
            self.stop_btn.set_state(True, False)
            self.stop_btn.clicked.connect(lambda: self.start_stop_action("STOP"))
            start_stop_layout.addWidget(self.start_btn)
            start_stop_layout.addWidget(self.stop_btn)
            button_layout.addLayout(start_stop_layout)
            # 6.2 패널 내부 버튼 레이아웃 Spacer
            button_layout.addStretch(1)
            # 6.3 숫자 키패드 (1~9, 0)
            keypad_layout = QGridLayout()
            keypad_layout.setContentsMargins(0, 0, 0, 0)
            keypad_layouy_spacing = 10
            keypad_size = 46
            keypad_layout.setSpacing(keypad_layouy_spacing)
            
            positions = [(i, j) for i in range(3) for j in range(3)]
            for pos, num in zip(positions, range(1, 10)):
                btn = CustomPushButton(str(num))
                btn.setFixedSize(keypad_size, keypad_size)
                btn.clicked.connect(lambda _, n=num: self.keypad_action(n))
                keypad_layout.addWidget(btn, pos[0], pos[1])
                
            zero_btn = CustomPushButton("0")
            zero_btn.setFixedSize(keypad_size * 3 + keypad_layouy_spacing * 2, keypad_size)
            zero_btn.clicked.connect(lambda: self.keypad_action(0))
            keypad_layout.addWidget(zero_btn, 3, 0, 1, 3)  # 0 버튼은 3행 1열부터 시작하여 1행을 차지
            button_layout.addLayout(keypad_layout)
            # 6.4 패널 내부 버튼 레이아웃 Spacer
            button_layout.addStretch(1)
            # 6.5 방향키 (위/아래)
            direction_layout = QVBoxLayout()
            up_btn = UpDownButton('up')
            up_btn.clicked.connect(lambda: self.updownkey_action('up'))
            down_btn = UpDownButton('down')
            down_btn.clicked.connect(lambda: self.updownkey_action('down'))
            direction_layout.addWidget(up_btn)
            direction_layout.addWidget(down_btn)
            button_layout.addLayout(direction_layout)
            # 6.6 패널 내부 버튼 레이아웃 Spacer
            button_layout.addStretch(1)
            # 6.7 CONFIRM / CLEAR 버튼
            confirm_clear_layout = QVBoxLayout()
            confirm_btn = CustomPushButton("CONFIRM")
            confirm_btn.setFixedSize(120, 100)
            confirm_btn.clicked.connect(self.comfrim_action)
            clear_btn = CustomPushButton("CLEAR")
            clear_btn.setFixedSize(120, 100)
            clear_btn.clicked.connect(self.clear_action)
            confirm_clear_layout.addWidget(confirm_btn)
            confirm_clear_layout.addWidget(clear_btn)
            button_layout.addLayout(confirm_clear_layout)
            # 패널 내부 레이아웃에 위젯 추가 종료 --------------------------------------------------------
            
            # 하단 볼트 체결 부분
            left_panel.addLayout(self.add_nut_layout())
        if True:
            # 오른쪽 패널 상단 볼트 체결 부분
            right_panel.addLayout(self.add_nut_layout())
            
            # 패널 내부 레이아웃 설정
            panel_hbox = QHBoxLayout()
            panel_in_vbox = QVBoxLayout()
            panel_in_vbox.setSpacing(5)
            
            panel_hbox.setContentsMargins(40, 0, 40, 0)
            panel_hbox.addLayout(panel_in_vbox)
            right_panel.addLayout(panel_hbox)
            
            # 패널 내부 레이아웃에 위젯 추가 시작 --------------------------------------------------------
            # 1. 패널 상단 제목 추가
            title_label = QLabel("Signal Trend Graph", self)
            title_label.setAlignment(Qt.AlignCenter)
            title_label.setFont(QFont("Arial", 16, QFont.Bold))
            title_label.setStyleSheet("background-color: rgb(121, 121, 121); color: white; padding: 10px; border: 2px solid black;")
            panel_in_vbox.addWidget(title_label)
            # 2. 패널 내부 Spacer 추가
            panel_in_vbox.addStretch(1)
            # 3. 그래프 패널
            self.plot_widget = pg.PlotWidget()
            self.plot_widget.setBackground((134, 128, 116))  # 배경색 설정
            panel_in_vbox.addWidget(self.plot_widget)
            
            # y축 변경 ======================================================
            plot_item = self.plot_widget.getPlotItem()
            # 기존 2, 2 아이템 삭제
            existing_item = plot_item.layout.itemAt(2, 2)
            plot_item.layout.removeItem(existing_item)
            # 기존 왼쪽 y 축 제거
            plot_item.hideAxis('left')
            # 오른쪽 y 축 추가
            right_axis = pg.AxisItem(orientation='right')
            right_axis.setTextPen(pg.mkPen(color='black'))
            right_axis.setStyle(tickFont=QFont("Arial", 11, QFont.Bold))
            plot_item.layout.addItem(right_axis, 2, 2)  # ✅ 올바른 위치
            right_axis.linkToView(plot_item.vb)
            # y 축 단위 추가            
            label = LabelItem(text="[mA]", angle=0, color='black', justify='left')
            label.item.setFont(QFont("Arial", 11, QFont.Bold))
            plot_item.layout.addItem(label, 1, 3)  # (row=0, col=2): 오른쪽 축 위
            # x축 변경 ======================================================
            bottom_axis = plot_item.getAxis('bottom')
            bottom_axis.setTextPen(pg.mkPen(color='black'))
            bottom_axis.setStyle(tickFont=QFont("Arial", 11, QFont.Bold))
            # x축 단위 추가
            label = LabelItem(text="[ms]", angle=0, color='black', justify='left')
            label.item.setFont(QFont("Arial", 11, QFont.Bold))
            plot_item.layout.addItem(label, 3, 0) 
            
            # ViewBox 접근
            view_box = self.plot_widget.getViewBox()
            view_box.setBackgroundColor('black')
            
            # GridItem 생성 및 추가
            self.grid_item = CustomGrid()
            view_box.addItem(self.grid_item)
            
            # # 기존 x, y 값
            # x = [0, 1, 1.01, 2, 3, 4, 4.01,   5, 6, 7, 7.01,   8, 9]
            # y = [0, 1, 0,   0, 0, 2, 0,     0, 0, 1, 0,        0, 0]
            
            # def to_pulse_shape(x, y):
            #     """x, y 데이터를 펄스(계단형)로 변환"""
            #     x_pulse = []
            #     y_pulse = []
            #     for i in range(len(x) - 1):
            #         x_pulse.extend([x[i], x[i+1]])
            #         y_pulse.extend([y[i], y[i]])
            #     return x_pulse, y_pulse
            
            # # 계단형으로 변환
            # x_pulse, y_pulse = to_pulse_shape(x, y)
            # self.plot_widget.plot(x_pulse, y_pulse, pen=pg.mkPen(color='white', width=2))
            
            # 실시간 그래프 그리용            
            self.x_start = 0
            self.x_skip = 0
            self.x_data = []
            self.y_data = []
            self.plot_widget.setYRange(-5, 300)
            self.plot_curve = self.plot_widget.plot([], [], pen=pg.mkPen(color='white', width=2))
            
            # 4. 패널 내부 Spacer 추가
            panel_in_vbox.addStretch(1)
            # 오른쪽 패널 하단 볼트 체결 부분
            right_panel.addLayout(self.add_nut_layout())

    def add_nut_layout(self):
        nut_path = './Pygui/vault.svg'
        nut_label_1 = QLabel(self)
        nut_label_1.setPixmap(QPixmap(nut_path).scaled(VAULT_SIZE, VAULT_SIZE, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        nut_label_2 = QLabel(self)
        nut_label_2.setPixmap(QPixmap(nut_path).scaled(VAULT_SIZE, VAULT_SIZE, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        
        vault_layout = QHBoxLayout()
        vault_layout.addWidget(nut_label_1)
        vault_layout.addStretch() # 가운데 여백 추가
        vault_layout.addWidget(nut_label_2)
        return vault_layout

    def start_stop_action(self, action):
        if action == "START":
            self.start_btn.set_state(True, self.net_state)
            self.stop_btn.set_state(False, self.net_state)
            self.sim_state = True
            
            # Client Thread 시작
            if self.client_thread is None or not self.client_thread.isRunning():
                self.client_thread = TCPClient()
                self.client_thread.received.connect(self.display_client_message)
                self.client_thread.data_received.connect(self.display_message)
                self.client_thread.server_state.connect(self.change_server_state)
                self.client_thread.start()
            else:
                print("Client thread is already running.")
            self.client_thread.change_tcp_model_run(True)  # TCP 클라이언트 스레드 시작
            
        elif action == "STOP":
            self.start_btn.set_state(False, self.net_state)
            self.stop_btn.set_state(True, self.net_state)
            self.sim_state = False
            self.client_thread.change_tcp_model_run(False)  # TCP 클라이언트 스레드 중지
        print(f"Simulation state changed to: {self.sim_state}")
    
    def keypad_action(self, number):
        target_value = int(self.target_cps_value.text())
        new_value = target_value * 10 + number
        
        if new_value > 10000000000:  # 최대/최소값 제한
            new_value = 10000000000
        
        self.target_cps_value.setText(str(new_value))
        # 10^x 표시 업데이트
        exp = 0
        while new_value >= 10:
            new_value /= 10
            exp += 1
        self.target_cps_exp_value.setText(f"{new_value:.2f} x 10^{exp}")
        print(f"Keypad pressed: {number}, Target CPS: {self.target_cps_value.text()}")
    
    def updownkey_action(self, direction):
        target_value = int(self.target_cps_value.text())
        if direction == 'up':
            new_value = target_value + 1
        elif direction == 'down':
            new_value = target_value - 1
        
        if new_value > 10000000000:  # 최대/최소값 제한
            new_value = 10000000000
        elif new_value < 0:
            new_value = 0
        
        self.target_cps_value.setText(str(new_value))
        # 10^x 표시 업데이트
        # 10^x 표시 업데이트
        exp = 0
        while new_value >= 10:
            new_value /= 10
            exp += 1
        self.target_cps_exp_value.setText(f"{new_value:.2f} x 10^{exp}")
        print(f"Up/Down pressed: {direction}, Target CPS: {self.target_cps_value.text()}")
    
    def clear_action(self):
        self.target_cps_value.setText("0")
        self.target_cps_exp_value.setText("0.00 x 10^0")
        print("Clear pressed, Target CPS reset to 0")
    
    def comfrim_action(self):
        # CONFIRM 버튼 동작 구현
        print("Confirm action executed")
        # 1. 현재 CPS 값 업데이트
        self.current_cps_value.setText(self.target_cps_value.text())
        self.current_cps_exp_value.setText(self.target_cps_exp_value.text())
        
        # 2. TCP 서버에 명령 전송
        if self.client_thread and self.client_thread.isRunning():
            cmd_str = self.current_cps_value.text()
            self.client_thread.send_message(cmd_str)
            print(f"Sent command: {cmd_str} to server")
    
    # ========== TCP 서버 통신 및 그래프 업데이트 관련 ================================
    def display_client_message(self, message):
        print(f"Received message from client: {message}")
        
    def display_message(self, message):
        """ 5개 받는 경우 [POS, VAL]"""
        # PACKET_SIZE = 5
        # for i in range(0, len(message), PACKET_SIZE):
        #     segment = message[i:i + PACKET_SIZE]
        #     if len(segment) < PACKET_SIZE:
        #         print("Incomplete packet detected, skipping.")
        #         continue
            
        #     raw_val_0 = segment[0]
        #     raw_val_1 = struct.unpack('<f', segment[1:5])[0]
        #     # print(f"[{i // PACKET_SIZE}] raw_val_0: {raw_val_0}, raw_val_1: {raw_val_1:.6f}")
            
        #     self.x_data.append(self.x_start)  # 순차적인 인덱스 (또는 timestamp)
        #     self.y_data.append(raw_val_1)
            
        #     self.x_start += 0.00002  # x축 간격 (20ns 단위로 증가)
        
        """ 4개 받는 경우 [VAL]"""
        PACKET_SIZE = 4
        for i in range(0, len(message), PACKET_SIZE):
            segment = message[i:i + PACKET_SIZE]
            if len(segment) < PACKET_SIZE:
                print("Incomplete packet detected, skipping.")
                continue
            
            # raw_val_0 = segment[0]
            raw_val_1 = struct.unpack('<f', segment)[0]
            # print(f"[{i // PACKET_SIZE}] raw_val_0: {raw_val_0}, raw_val_1: {raw_val_1:.6f}")
            
            if PLOT_SKIP == 0:
                # SKIP 고려하지 않고 그래프 저장
                self.x_data.append(self.x_start)  # 순차적인 인덱스 (또는 timestamp)
                self.y_data.append(raw_val_1)
            elif self.x_skip % PLOT_SKIP == 0:
                # SKIP 고려해서 그래프 저장
                self.x_data.append(self.x_start)  # 순차적인 인덱스 (또는 timestamp)
                self.y_data.append(raw_val_1)
            
            self.x_start += 0.00002  # x축 간격 (20ns 단위로 증가)
            self.x_skip += 1 # skip용.
            
        # 일정 길이 이상 시 자르기 (예: 2048개 유지)
        MAX_POINTS = 2048 * 10 # 4.096 ms 윈도우만 표기.
        if len(self.x_data) > MAX_POINTS:
            self.x_data = self.x_data[-MAX_POINTS:]
            self.y_data = self.y_data[-MAX_POINTS:]

        # 그래프 갱신
        self.plot_curve.setData(self.x_data, self.y_data)
            
        # print('Display message completed.')
        
    def change_server_state(self, state):
        print(f"Server state changed: {state}")
        self.net_state = state
        
        self.start_btn.set_state(True, self.net_state)
        self.stop_btn.set_state(False, self.net_state)
        self.sim_state = True
    # ===============================================================================

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = MainWidget()
    ex.show()
    app.exec_()


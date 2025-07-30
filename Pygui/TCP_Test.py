import socket
import struct

HOST = '192.168.1.10'   # 보드 IP 주소로 변경
PORT = 7             # 보드 포트


s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))

print(f"Connected to {HOST}:{PORT}")

# 명령 전송 (문자열로 보내야 서버가 atoi 처리 가능)
cmd_str = "0"
s.sendall(cmd_str.encode())

print(f"Sent command: {cmd_str}")
chunk = s.recv(65536)

print(len(chunk))

# 명령 전송 (문자열로 보내야 서버가 atoi 처리 가능)
cmd_str = "1"
s.sendall(cmd_str.encode())

print(f"Sent command: {cmd_str}")
chunk = s.recv(65536)

print(len(chunk))
# 수신 데이터 파싱
PACKET_SIZE = 5
for i in range(0, len(chunk), PACKET_SIZE):
    segment = chunk[i:i + PACKET_SIZE]
    if len(segment) < PACKET_SIZE:
        print("Incomplete packet detected, skipping.")
        continue
    
    raw_val_0 = segment[0]
    raw_val_1 = struct.unpack('<f', segment[1:5])[0]
    print(f"[{i // PACKET_SIZE}] raw_val_0: {raw_val_0}, raw_val_1: {raw_val_1:.6f}")

# 명령 전송 (문자열로 보내야 서버가 atoi 처리 가능)
cmd_str = "2"
s.sendall(cmd_str.encode())

print(f"Sent command: {cmd_str}")
chunk = s.recv(65536)

print(len(chunk))
# 수신 데이터 파싱
PACKET_SIZE = 5
for i in range(0, len(chunk), PACKET_SIZE):
    segment = chunk[i:i + PACKET_SIZE]
    if len(segment) < PACKET_SIZE:
        print("Incomplete packet detected, skipping.")
        continue
    
    raw_val_0 = segment[0]
    raw_val_1 = struct.unpack('<f', segment[1:5])[0]
    print(f"[{i // PACKET_SIZE}] raw_val_0: {raw_val_0}, raw_val_1: {raw_val_1:.6f}")

print('Done')
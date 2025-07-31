import pandas as pd



# CSV 파일 경로 지정
file_path = './PyPulseSample/pulse_n.csv'  # <-- 파일 경로를 적절히 수정하세요

# CSV 파일 불러오기
df = pd.read_csv(file_path)

# 특정 열 지정 (예: 첫 번째 열)
column_name = df.columns[0]  # 또는 'ColumnName'으로 직접 지정 가능

# 20개 간격으로 값 추출
sampled_values = df['y_tun'][::50].reset_index(drop=True)

# 결과 확인
# print(sampled_values)

# 결과를 새로운 CSV로 저장 (선택)
sampled_values.to_csv('./PyPulseSample/pulse_n_50.csv', index=False)

# CSV 파일 경로 지정
file_path = './PyPulseSample/pulse_g.csv'  # <-- 파일 경로를 적절히 수정하세요

# CSV 파일 불러오기
df = pd.read_csv(file_path)

# 특정 열 지정 (예: 첫 번째 열)
column_name = df.columns[0]  # 또는 'ColumnName'으로 직접 지정 가능

# 20개 간격으로 값 추출
sampled_values = df['y_tun'][::50].reset_index(drop=True)

# 결과 확인
# print(sampled_values)

# 결과를 새로운 CSV로 저장 (선택)
sampled_values.to_csv('./PyPulseSample/pulse_g_50.csv', index=False)
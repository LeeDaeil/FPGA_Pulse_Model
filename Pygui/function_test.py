import random

def calculate_chunks_for_xcps(x_cps, slots_per_chunk=2028, time_per_slot_ns=20):
    # 청크 시간 (초 단위)
    chunk_time_sec = (slots_per_chunk * time_per_slot_ns) * 1e-9
    # 펄스 하나 당 청크 수
    chunks_needed = 1 / (x_cps * chunk_time_sec)
    return int(chunks_needed)

x_cps = 1
needed_chunks = calculate_chunks_for_xcps(x_cps)
print(f"{x_cps} cps를 만들기 위해 필요한 청크 수: {needed_chunks}")

x_cps = 200
needed_chunks = calculate_chunks_for_xcps(x_cps)
print(f"{x_cps} cps를 만들기 위해 필요한 청크 수: {needed_chunks}")


def assign_pulses_to_chunks(x_cps, total_chunks):
    # Step 1: Initialize 빈 리스트
    pulses_per_chunk = [0] * total_chunks

    # Step 2: 랜덤하게 x_cps개의 펄스를 청크에 분배
    for _ in range(x_cps):
        idx = random.randint(0, total_chunks - 1)
        pulses_per_chunk[idx] += 1

    return pulses_per_chunk

# 예시: 총 100 청크, 200 cps 요청
cps = 200
total_chunks = 123
pulse_distribution = assign_pulses_to_chunks(cps, total_chunks)

# 결과 확인
print(f"총 펄스: {sum(pulse_distribution)}")
print(f"펄스 분포: {pulse_distribution}")
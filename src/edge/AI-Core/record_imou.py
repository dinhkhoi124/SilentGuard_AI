import sys
import subprocess
import os
from ver9 import get_imou_live_stream_url

def main():
    if len(sys.argv) < 3:
        print("Sử dụng: python record_imou.py <tên_file.mp4> <số_giây>")
        print("Ví dụ: python record_imou.py S1_ID_Swap.mp4 60")
        return

    output_file = sys.argv[1]
    
    if os.path.exists(output_file):
        print(f"[LỖI] File '{output_file}' đã tồn tại! Vui lòng chọn tên khác hoặc xoá file cũ để tránh mất dữ liệu quý giá.")
        return
        
    try:
        duration = int(sys.argv[2])
    except ValueError:
        print(f"[LỖI] Số giây '{sys.argv[2]}' không hợp lệ. Vui lòng nhập một số nguyên (ví dụ: 60).")
        return

    print("Đang lấy URL luồng trực tiếp từ API Imou...")
    try:
        url = get_imou_live_stream_url()
    except Exception as e:
        print(f"[LỖI] Không lấy được URL: {e}")
        return

    print(f"Đã lấy URL thành công. Bắt đầu ghi nguyên bản luồng gốc trong {duration} giây...")
    print(f"Lưu ra file: {output_file}")
    
    # Lệnh ffmpeg sử dụng -c copy để giữ nguyên 100% bitstream gốc, không re-encode
    command = [
        "ffmpeg", 
        "-i", url,          # Đầu vào là luồng trực tiếp
        "-t", str(duration),# Giới hạn thời gian ghi (giây)
        "-c", "copy",       # Copy nguyên gốc (giữ đúng fps, độ phân giải)
        output_file
    ]
    
    try:
        subprocess.run(command, check=True)
        print(f"\n[THÀNH CÔNG] Đã lưu file: {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"\n[LỖI] FFmpeg gặp sự cố: {e}")
    except FileNotFoundError:
        print("\n[LỖI] Không tìm thấy 'ffmpeg'. Hãy đảm bảo ffmpeg đã được cài đặt và thêm vào PATH của Windows.")

if __name__ == "__main__":
    main()

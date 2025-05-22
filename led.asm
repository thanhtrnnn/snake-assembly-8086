.MODEL SMALL
.STACK 100H

.DATA
    ; Khai báo địa chỉ cổng cho 8255 Programmable Peripheral Interface (PPI)
    ; Các địa chỉ này có thể cụ thể cho thiết lập phần cứng của bạn.
    PORTA EQU 00H       ; Địa chỉ cổng A của 8255 PPI, dùng để gửi dữ liệu đến LED 7 đoạn.
    PORT_CON EQU 06H    ; Địa chỉ cổng điều khiển của 8255 PPI, dùng để cấu hình PPI.
                        ; Địa chỉ 8255 điển hình: PortA=Base, PortB=Base+1, PortC=Base+2, Control=Base+3.
                        ; Giá trị 00H và 06H gợi ý một ánh xạ phần cứng không chuẩn hoặc cụ thể.

    DELAY_COUNT DW 1FFFH ; Hằng số dùng để tạo độ trễ. Điều chỉnh giá trị này để thay đổi tốc độ hiển thị.
                         ; Giá trị lớn hơn có nghĩa là độ trễ dài hơn cho mỗi chữ số.

    ; Mã hiển thị LED 7 đoạn cho các chữ số 0-9.
    ; Giả định sử dụng LED loại cathode chung (mức \'0\' BẬT segment, \'1\' TẮT segment).
    ; Thứ tự bit: Bit 7 (MSB) = dp (dấu chấm thập phân), Bit 6 = g, Bit 5 = f, ..., Bit 0 (LSB) = a.
    ; dp được giả định là TẮT (đặt thành 1).
    NUM DB 11000000B,  ; 0: Các segment a,b,c,d,e,f BẬT (dp=1, g=1, f=0, e=0, d=0, c=0, b=0, a=0)
           11111001B,  ; 1: Các segment b,c BẬT       (dp=1, g=1, f=1, e=1, d=1, c=0, b=0, a=1)
           10100100B,  ; 2: Các segment a,b,d,e,g BẬT (dp=1, g=0, f=1, e=0, d=0, c=1, b=0, a=0)
           10110000B,  ; 3: Các segment a,b,c,d,g BẬT (dp=1, g=0, f=1, e=1, d=0, c=0, b=0, a=0)
           10011001B,  ; 4: Các segment b,c,f,g BẬT   (dp=1, g=0, f=0, e=1, d=1, c=0, b=0, a=1)
           10010010B,  ; 5: Các segment a,c,d,f,g BẬT (dp=1, g=0, f=0, e=1, d=0, c=0, b=1, a=0)
           10000010B,  ; 6: Các segment a,c,d,e,f,g BẬT (dp=1, g=0, f=0, e=0, d=0, c=0, b=1, a=0)
           11111000B,  ; 7: Các segment a,b,c BẬT     (dp=1, g=1, f=1, e=1, d=1, c=0, b=0, a=0) - Đã sửa
           10000000B,  ; 8: Các segment a,b,c,d,e,f,g BẬT (dp=1, g=0, f=0, e=0, d=0, c=0, b=0, a=0)
           10010000B   ; 9: Các segment a,b,c,d,f,g BẬT (dp=1, g=0, f=0, e=1, d=0, c=0, b=0, a=0)

.CODE
MAIN PROC
    ; Khởi tạo thanh ghi Data Segment (DS)
    MOV AX, @DATA       ; Lấy địa chỉ của segment .DATA
    MOV DS, AX          ; Đặt DS thành địa chỉ này

START_DISPLAY_CYCLE:
    ; Cấu hình 8255 PPI: Cổng A là output
    MOV DX, PORT_CON    ; Nạp địa chỉ cổng điều khiển vào DX
    MOV AL, 80H         ; Nạp từ điều khiển vào AL.
                        ; 80H (10000000B) thường cấu hình:
                        ; - Cờ Mode Set = 1 (hoạt động)
                        ; - Nhóm A (Cổng A và Cổng C trên) ở Mode 0 (I/O cơ bản)
                        ; - Cổng A là output
                        ; - Cổng C trên là output
                        ; - Nhóm B (Cổng B và Cổng C dưới) ở Mode 0
                        ; - Cổng B là output
                        ; - Cổng C dưới là output
                        ; Điều này làm cho Cổng A trở thành cổng output.
    OUT DX, AL          ; Gửi từ điều khiển đến cổng điều khiển 8255

    ; Khởi tạo cho vòng lặp qua các chữ số
    MOV CX, 10          ; Đặt bộ đếm vòng lặp thành 10 (cho các chữ số từ 0 đến 9)
    MOV SI, OFFSET NUM  ; Trỏ thanh ghi SI (Source Index) đến đầu mảng NUM

DISPLAY_NEXT_DIGIT:
    MOV BX, DELAY_COUNT ; Nạp thời gian trễ vào BX cho thời gian hiển thị của chữ số hiện tại

INNER_DELAY_LOOP:
    ; Hiển thị chữ số hiện tại
    MOV AL, [SI]        ; Nạp mã 7 đoạn cho chữ số hiện tại (được trỏ bởi SI) vào AL
    MOV DX, PORTA       ; Nạp địa chỉ cổng A vào DX
    OUT DX, AL          ; Gửi mã 7 đoạn trong AL đến cổng A, làm sáng các segment LED

    ; Giảm bộ đếm độ trễ
    DEC BX              ; BX = BX - 1
    JNZ INNER_DELAY_LOOP; Nhảy đến INNER_DELAY_LOOP nếu BX khác không (tiếp tục hiển thị chữ số hiện tại)

    ; Chuyển sang chữ số tiếp theo
    INC SI              ; Tăng SI để trỏ đến mã 7 đoạn tiếp theo trong mảng NUM
    LOOP DISPLAY_NEXT_DIGIT ; Giảm CX; nếu CX khác không, nhảy đến DISPLAY_NEXT_DIGIT

    ; Khởi động lại chu kỳ từ 0 đến 9
    JMP START_DISPLAY_CYCLE ; Sau khi hiển thị tất cả 10 chữ số, nhảy về đầu để lặp lại

MAIN ENDP

; Kết thúc chương trình
END MAIN
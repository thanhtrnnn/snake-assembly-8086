; SNAKE GAME FOR 8086 ASSEMBLY
; Modified features:
; - Name input
; - Welcome/menu screen ('Welcome, (playerName)', New Game, Settings, Exit)
; - Main game (3 lives, random reward, wall-bounded, self-collision, accumulated score)
; - Play again/name re-entry on game over

; Requirements:
; - Capitalized opcode & registers name, normal functions & variables name
; - Short yet readable functions & variables name
; - 80 x 25 screen strictly
; - Centered/ near-centered menu/ instructions

.Model Small
.Stack 100h
.Data
    ; Player name
    namePrompt DB "Enter your name: $"
    playerName DB 16 dup('$')
    nameLen DB 0
    welcome DB "Welcome, $"
    
    ; --- Main menu ---
    t0 DB " _____ _   _  ___  _   _______ "
    t1 DB "/  ___| \ | |/ _ \| | / |  ___|"
    t2 DB "\ `--.|  \| / /_\ | |/ /| |__  "
    t3 DB " `--. | . ` |  _  |    \|  __| "
    t4 DB "/\__/ | |\  | | | | |\  | |___ "
    t5 DB "\____/\_| \_\_| |_\_| \_\_____/"    
    menuOption1 DB "1. New Game$"
    menuOption2 DB "2. Settings$"
    menuOption3 DB "3. Exit$"
    ; ---
    
    ; --- Ingame --- 
    lives DB "LIVES:", 3, 3, 3 ; Lives display
    foods DW ? ; Food location
    livesLeft DB 3 ; Lives counter
    scoreString DB "SCORE: $"
    totalScore DB 0   ; Accumulated score across lives
    ; Obstacle data
    line1 DW 80*8+20 ; Row 11, Col 20 (centered)
    len1  DB 40        ; 40 characters wide
    line2 DW 80*16+20 ; Row 13, Col 20 (centered)
    len2  DB 40        ; 40 characters wide
    ; ---

    ; --- Snake Info ---
    start_position equ 2000 ; Middle screen position for 80x25
    position DW start_position, 100 dup(0) ; Snake segment screen positions
    snake DB '@', 100 dup(0) ; Snake character segments
    snakeLen DB 1 ; Snake length
    ; ---
    
    
    ; --- Game over ---
    gameOver DB "Game Over"
    endtxt DB "Restart ? (y / n)"
    newHighScore DB "New High Score! $"
    ; ---

    ; Special parameters
    two DW 2
    map DW 3500
    endline DW 160 ; 80 columns * 2 bytes per cell
    
    ; --- Settings ---
    settingsTitle DB "SETTINGS$"
    difficultyOption DB "Difficulty: $"
    difficultyEasy DB "Easy$"
    difficultyMedium DB "Medium$"
    difficultyHard DB "Hard$"
    difficultyLevel DB 2 ; 1=Easy, 2=Medium, 3=Hard
    controlsOption DB "Controls: WASD to move, ESC for menu$"
    backOption DB "Press ESC to go back$"
    changeDiffOption DB "Press 1-3 to change difficulty$"
    ; ---

.Code
start:
    MOV AX, @Data ; Đưa địa chỉ đoạn Data vào AX
    MOV DS, AX ; Gán lại vào thanh ghi DS để truy cập các biến trong Data
    
    ; Thiết lập segment video để vẽ màn hình
    MOV AX, 0b800h ; 0b800h - địa chỉ đầu của vùng nhớ video ở chế độ văn bản. 2byte: ký tự + màu
    MOV ES, AX ; đưa địa chỉ video vào ES, dùng cho việc ghi dữ liệu ra màn hình
    
    ; Đặt chế độ màn hình văn bản 80x25
    MOV AH, 0 ; Hàm 0 của ngắt 10h: Đặt chế độ hiển thị
    MOV AL, 3 ; Chế độ 3: Văn bản 80x25: 80 cột x 25 dòng, 16 màu
    INT 10h ; ngắt bios để đổi chế độ, reset màn hình về chế độ text
        
    ; Đặt vị trí con trỏ văn bản
    MOV AH, 2 ; Hàm 2 của ngắt 10h: đặt vị trí con trỏ nhấp nháy trên màn hình văn bản
    MOV DH, 10 ; con trỏ ở dòng thứ 11, vì dòng đầu tiên là 0
    MOV DL, 25 ; con trỏ ở cột thứ 26
    INT 10h ; con trỏ chuyển đến vị trí (11, 26)
    
    CALL get_name

    ; Ẩn con trỏ nhấp nháy
    MOV AH, 1 ; Hàm 1 của ngắt 10h: thay đổi hình dạng con trỏ văn bản
    MOV CH, 2BH ; CH là dòng bắt đầu của con trỏ (0-15), 2BH = 43 > 15 -> ẩn con trỏ
    MOV CL, 0BH ; CL là dòng kết thúc của con trỏ
    INT 10h ; Thực hiện thay đổi hình dạng con trỏ dựa trên CH và CL
    
    CALL main_menu

start_again:
    CALL clearall
    MOV position, start_position ; Reset vị trí của con rắn
    CALL draw
    XOR CL, CL ; Xoá thanh ghi CL, CL lưu hướng trước đó
    XOR DL, DL ; Xoá thanh ghi DL, DL lưu hướng vừa thay đổi
    MOV DL, 'D' ; Đặt hướng mặc định ban đầu là sang phải, nút 'D'

game_loop: ; wait for input, validate and move
    MOV AH, 1       ; Check for keystroke
    INT 16H
    JZ decide_move  ; No key pressed, ZF = 0, use current DL (which holds last direction/ default)

    MOV AH, 0       ; Key was pressed, get it
    INT 16H
    AND AL, 0DFH    ; Convert to uppercase, unset 6th bit and preserve the rest (0DFh = 11011111b)

    CMP AL, 27      ; ESC key?
    JE return_to_menu

    ; AL has the new potential direction
    ; CL has the last ACTUAL direction moved (from previous move_... call)
    ; DL has the current direction (will be updated if AL is valid and not opposite)

    ; Check W key ('Up')
    CMP AL, 'W'
    JNE checkDown
    CMP CL, 'S'     ; Was last move 'S' (Down)?
    JE decide_move  ; Yes, 'W' is opposite, so ignore AL, keep current DL
    MOV DL, 'W'     ; No, update DL to 'W'
    JMP decide_move

checkDown:
    CMP AL, 'S'     ; Check S key ('Down')
    JNE checkLeft
    CMP CL, 'W'     ; Was last move 'W' (Up)?
    JE decide_move  ; Yes, 'S' is opposite
    MOV DL, 'S'     ; No, update DL to 'S'
    JMP decide_move

checkLeft:
    CMP AL, 'A'     ; Check A key ('Left')
    JNE checkRight
    CMP CL, 'D'     ; Was last move 'D' (Right)?
    JE decide_move  ; Yes, 'A' is opposite
    MOV DL, 'A'     ; No, update DL to 'A'
    JMP decide_move

checkRight:
    CMP AL, 'D'     ; Check D key ('Right')
    JNE decide_move ; Not 'D', so not a valid direction key for this check path
    CMP CL, 'A'     ; Was last move 'A' (Left)?
    JE decide_move  ; Yes, 'D' is opposite
    MOV DL, 'D'     ; No, update DL to 'D'
    JMP decide_move

decide_move:
    ; DL now contains the direction to move (either newly set, previous, or default)
    ; CL will be updated with DL after the move in the respective move_... procedure
    CMP DL, 'A'
    JE move_left
    CMP DL, 'D'
    JE move_right
    CMP DL, 'W'
    JE move_up
    CMP DL, 'S'
    JE move_down
    JMP game_loop ; Fallback, should not be reached if DL is always valid
    
move_left:
    CALL left
    MOV CL, DL ; Save direction for next cycle
    JMP game_loop
    
move_right:
    CALL right
    MOV CL, DL ; Save direction for next cycle
    JMP game_loop
    
move_up:
    CALL up
    MOV CL, DL ; Save direction for next cycle
    JMP game_loop
    
move_down:
    CALL down
    MOV CL, DL ; Save direction for next cycle
    JMP game_loop
    
return_to_menu:
    CALL main_menu
    JMP start_again

exit:
    MOV AH, 4CH
    INT 21h     

; Nhập tên người chơi
get_name PROC
    CALL clearall

    ; Hiển thị lời 'enter your name'
    prompt:
        MOV AH, 2 ; Đặt vị trí con trỏ nhấp nháy
        MOV DH, 10
        MOV DL, 25 ; vị trí (11,26)
        MOV BH, 0 ; page video mặc định
        INT 10h ; thực thi
        
        MOV AH, 9 ; in chuỗi ra màn hình
        LEA DX, namePrompt ; DX trỏ tới chuỗi namePrompt
        INT 21h ; thực hiện in

    ; Nhập tên
    XOR CX, CX ; xoá CX
    XOR SI, SI ; SI dùng làm chỉ số cho mảng playerName
    
    ; Lặp nhập từng ký tự
    input_loop:
        MOV AH, 1 ; Đọc 1 ký tự từ bàn phím, lưu vào AL
        INT 21h

        CMP AL, 8 ; Kiểm tra ấn nút backspace (ASCII 8)
        JE delete_char ; nhảy đến delete_char
        
        CMP AL, 13 ; Kiểm tra ấn nút enter (ASCII 13)
        JE end_input ; Nếu bằng thì nhảy đến end_input
        
        CMP CL, 15 ; Độ dài max có thể nhập
        JE input_loop
        
        MOV playerName[SI], AL ; Use SI for indexing
        INC SI
        INC CL
        JMP input_loop

    delete_char:
        CMP SI, 0
        JE input_loop       ; Không làm gì nếu chưa nhập gì

        DEC SI              ; Lùi lại chỉ số mảng
        DEC CL              ; Giảm số lượng ký tự đã nhập

        ; Di chuyển con trỏ trái 1 cột
        MOV AH, 2
        MOV BH, 0
        MOV DH, 10          ; Dòng nhập tên (giữ nguyên dòng)
        MOV DL, 42          ; Cột = vị trí bắt đầu nhập + SI
        ADD DX, SI
        INT 10h

        ; Ghi đè khoảng trắng để xoá ký tự
        MOV AH, 0Eh
        MOV AL, ' '
        INT 10h

        ; Di chuyển con trỏ lại vị trí đã xoá
        DEC DL
        MOV AH, 2
        INT 10h

        JMP input_loop
        
    ; Kết thúc nhập
    end_input:
        MOV nameLen, CL ; Lưu độ dài tên vào biến nameLen
        MOV playerName[SI], '$' ; Đặt '$' kết thúc chuỗi để hỗ trợ in bằng MOV AH, 9
        RET ; trả về thủ tục gọi
get_name ENDP

; Hiển thị lựa chọn main_menu
main_menu PROC
    CALL clearall
    
    ; Hiển thị tiêu đề ASCII 'SNAKE'
    MOV DI, (3*80+25)*2 ; Tính địa chỉ của ký tự, lưu vào DI
    LEA SI, t0 ; Lấy địa chỉ dòng t0 lưu vào SI
    MOV CX, 31 ; Số ký tự cần in là 31
    d0:
        MOVSB ; Di chuyển 1 byte từ DS:SI đến ES:DI, SI += 1, DI += 1 -> chép ký tự từ t0 ra màn hình
        INC DI ; Chỉ tăng địa chỉ DI lên 1 byte vì ko dùng thuộc tính màu
        LOOP d0 ; lặp khi CX != 0
    
    MOV DI, (4*80+25)*2
    LEA SI, t1
    MOV CX, 31
    d1:
        MOVSB
        INC DI
        LOOP d1
    
    MOV DI, (5*80+25)*2
    LEA SI, t2
    MOV CX, 31
    d2:
        MOVSB
        INC DI
        LOOP d2 
    
    MOV DI, (6*80+25)*2
    LEA SI, t3
    MOV CX, 31
    d3:
        MOVSB
        INC DI
        LOOP d3 

    MOV DI, (7*80+25)*2
    LEA SI, t4
    MOV CX, 31
    d4:
        MOVSB
        INC DI
        LOOP d4
    
    MOV DI, (8*80+25)*2
    LEA SI, t5
    MOV CX, 31
    d5:
        MOVSB
        INC DI
        LOOP d5
    
    ; Hiển thị lời chào và tên người chơi
    MOV AH, 2 ; Đặt vị trí con trỏ nhấp nháy
    MOV DH, 10
    MOV DL, 25 ; Đặt tại vị trí (11,26)
    MOV BH, 0 ; page video mặc định
    INT 10h ; thực thi
    
    MOV AH, 9 ; in chuỗi ký tự ra màn hình
    LEA DX, welcome ; trỏ đến chuỗi welcome
    INT 21h ; thực hiện in
    
    MOV AH, 9
    LEA DX, playerName
    INT 21h
    
    ; Hiển thị các lựa chọn menu
    ; macro dùng để in một dòng lựa chọn tại dòng col và cột 32
    printOpt MACRO col, opt
        MOV AH, 2
        MOV DH, col
        MOV DL, 32
        INT 10h
        
        MOV AH, 9
        LEA DX, opt
        INT 21h
    ENDM
    
    printOpt 12, menuOption1
    printOpt 13, menuOption2
    printOpt 14, menuOption3
    
    ; Xử lý lựa chọn của người chơi
    menu_select:
        MOV AH, 0
        INT 16h ; Chờ người dùng bấm phím và lưu vào AL
        
        CMP AL, '1'
        JE start_game
        
        CMP AL, '2'
        JE show_settings
        
        CMP AL, '3'
        JE exit_game

        JMP menu_select
    
    ; Xử lý từng lựa chọn
    start_game:
        MOV totalScore, 0 ; reset điểm số về 0
        RET ; Kết thúc thủ tục main_menu
        
    show_settings:
        CALL settings_menu
        JMP main_menu
        
    exit_game: ; thoát chương trình
        MOV AH, 4CH
        INT 21h
        
    RET
main_menu ENDP

;Game screen 
draw PROC ; Draw game screen with border, score, lives, snake and food
    ; Draw border
    CALL border 

    ; Display score
    CALL print_score
    
    ; Display lives
    LEA SI, lives
    MOV DI, 130
    MOV CX, 9
    livesDisplay:
        MOVSB
        INC DI 
        LOOP livesDisplay
    
    ; Display player name
    MOV AH, 2
    MOV DH, 0
    MOV DL, 35
    MOV BH, 0
    INT 10h
    
    MOV AH, 9
    LEA DX, playerName
    INT 21h
    
    ; Draw snake
    XOR DX, DX 
    MOV DI, position
    MOV DL, snake 
    ES: MOV [DI], DL
    
    ; Draw obstacles
    ; Above line 1
    MOV CL, len1
    MOV DI, line1
    ADD DI, DI ; 2 bytes per cell
    draw_obs1:
        MOV AL, '#'
        ES: MOV [DI], AL
        ADD DI, 2
        LOOP draw_obs1
    ; Below line 2
    MOV CL, len2
    MOV DI, line2
    ADD DI, DI
    draw_obs2:
        MOV AL, '#'
        ES: MOV [DI], AL
        ADD DI, 2
        LOOP draw_obs2
        
    ; Place food
    CALL place_food
    RET
draw ENDP

; Snake movement procedures
; Move left
left PROC
    PUSH DX 
    CALL shift
    SUB position, 2
    
    CALL eat_food
    CALL move_snake
    CALL delays
    POP DX
    RET    
ENDP

; Move right
right PROC
    PUSH DX 
    CALL shift
    ADD position, 2
    
    CALL eat_food
    CALL move_snake 
    CALL delays
    POP DX
    RET    
ENDP

; Move up
up PROC
    PUSH DX 
    CALL shift
    SUB position, 160 ; 80 columns * 2 bytes per cell
    
    CALL eat_food
    CALL move_snake
    CALL delays
    POP DX
    RET    
ENDP

; Move down
down PROC
    PUSH DX 
    CALL shift
    ADD position, 160 ; 80 columns * 2 bytes per cell
    
    CALL eat_food
    CALL move_snake
    CALL delays
    POP DX
    RET    
ENDP

; Shift snake segments 
shift PROC
    ; Dịch chuyển các đoạn thân rắn về phía sau để cập nhật vị trí mới của đầu rắn
    PUSH AX
    XOR CH, CH         ; Xóa thanh ghi CH (dùng cho vòng lặp)
    XOR BH, BH         ; Xóa thanh ghi BH
    MOV CL, snakeLen   ; CL = chiều dài rắn hiện tại
    INC CL             ; Tăng CL lên 1 để dịch chuyển tất cả các đoạn (bao gồm cả đầu mới)
    MOV AL, 2          ; Mỗi vị trí chiếm 2 byte (word)
    MUL CL             ; AX = CL * 2 (tổng số byte cần dịch chuyển)
    MOV BL, AL         ; BL = tổng số byte
    XOR DX, DX         ; Xóa DX (dùng cho lưu vị trí tạm thời)

    ; Vòng lặp dịch chuyển từng đoạn thân rắn từ đuôi lên đầu
    shiftsnake:
        MOV DX, position[BX-2] ; Lấy vị trí của đoạn trước (BX-2)
        MOV position[BX], DX   ; Gán vị trí này cho đoạn hiện tại (BX)
        SUB BX, 2              ; Lùi về đoạn trước
        LOOP shiftsnake        ; Lặp lại cho đến khi hết các đoạn
    POP AX
    RET
ENDP
;Hàm này kiểm tra xem đầu rắn đã va chạm với thứ gì sau khi di chuyển
eat_food PROC 
    PUSH AX 
    PUSH CX 
    
    MOV DI, position ; lưu vị trí đầu của rắng vào DI
    ES: CMP [DI], 0
    JZ no
    ES: CMP [DI], 20h ; Kiểm tra xem có phải là khoảng trống không(20H)
    JZ wall
    ES: CMP [DI], '*' ; Kiểm tra xem có phải là thức ăn không
    JE addfood
    ES: CMP [DI], '#'  ; Kiểm tra xem có phải là chướng ngại vật không
    JE wallKnock 
    JNE wallKnock ; Nếu không rơi vào các trường hợp trên thì đã va chạm với thân rắn
    addfood:
        INC totalScore  ; Tăng Điểm
        MOV foods, 0 ; Reset foods (food position).
        XOR BH, BH 
        MOV BL, snakeLen 
        MOV snake[BX], 'o' ; Thêm một thành phần mới vào thân rắn (ký tự : 'o')
        ES: MOV [DI], 0 ; Xóa ký tự thức ăn cũ 
        ADD snakeLen, 1 ; Tăng chiều dài rắn lên 1
        CALL print_score ; In lại điểm số
        CALL place_food ; Đặt thức ăn mới
        JMP no ; Jump to no to finish.
        
    wall: ; Wall collision check
        CMP DI, 320 
        JBE wallKnock ; Top wall
        CMP DI, 3840
        JAE wallKnock ; Bottom wall
        MOV AX, DI
        MOV BL, 160 
        DIV BL
        CMP AH, 0 ; column 0
        JZ wallKnock ; Left wall
        MOV AX, DI
        ADD AX, 2
        MOV BL, 160
        DIV BL
        CMP AH, 0 ; column 79
        JZ wallKnock ; Right wall
        JMP no
        
    wallKnock: ; Handle collision
        XOR BH, BH 
        MOV BL, livesLeft
        SUB livesLeft, 1
        CMP livesLeft, 0
        JNZ rest ; livesLeft > 0, restart
        POP CX
        POP AX
        CALL game_over 
        
    rest: ; Restart with one less life
        MOV lives[BX+5], 0 ;  BX = ? → lives[?  + 5] = 0 (xoá mạng hiển thị)
        POP CX
        POP AX
        CALL restart
        
    no:
        POP CX
        POP AX
    RET
ENDP


place_food PROC ; Place food at random position
    PUSH AX ; Lưu lại giá trị tạm th
    PUSH DX

    lap:    
        MOV AH, 00h
        INT 1AH ; Sử dụng BIOS interrupt 1AH để lấy thời gian hệ thống(số tích đồng hồ từ nửa đêm)
        ; lưu tại thanh ghi CX:DX
        MOV AX, DX
        XOR DX, DX
        DIV map ; map = 3500, lấy giá trị random chia cho map, dư ra DX
        ADD DX, 2*(80*2 + 1) ; Cộng thêm giá trị đảm bảo vị trí thức ăn nằm trong vùng chơi
        MOV BX, DX 
        ; Đảm bảo vị trí thức ăn là số chẵn ( mỗi ô chiếm 2 byte) để không bị lệch
        MOV AX, DX  
        XOR DX, DX
        DIV two
        CMP DX, 0
        JNE lap ; nếu lẻ quay lại random
        
    ; Kiểm tra vị trí thức ăn có sát biên không
    XOR DX, DX 
    MOV AX, BX
    DIV endline ; endline = 160 ( 80 cột  * 2 bytes)  BX = BX / 160 (dư DX)
    CMP DX, 0 ; Nếu sát biên trái(DX = 0) nhảy tới in left
    JE inleft
    
    XOR DX, DX    
    MOV AX, BX
    ADD AX, 4
    DIV endline
    CMP DX, 0 ; Nếu sát biên phải(DX = 0) nhảy tới in right
    JE inright

    inleft: ; nếu sát biên trái dịch vào 1 ô
        ADD BX, 2
        JMP place
        
    inright: ; nếu sát biên phải dịch vào 1 ô
        SUB BX, 2
        
    place:    ; đặt thức ăn '*' vào vị trí được lưu tại BX
        ES: MOV [BX], '*'
        MOV foods, BX
        
    POP DX
    POP AX ; trả lại giá trị cho thanh ghi
    RET
place_food ENDP



move_snake PROC
    ; Vẽ lại toàn bộ rắn trên màn hình dựa vào mảng vị trí và ký tự từng đoạn
    XOR CH, CH         ; Xóa CH (dùng cho vòng lặp)
    XOR SI, SI         ; SI = chỉ số vị trí trong mảng position
    XOR DL, DL         ; DL = ký tự đoạn rắn
    MOV CL, snakeLen   ; CL = chiều dài rắn hiện tại
    XOR BX, BX         ; BX = chỉ số ký tự trong mảng snake

    ; Vòng lặp vẽ từng đoạn rắn lên màn hình
    move_segments:
        MOV DI, position[SI]   ; DI = vị trí màn hình của đoạn hiện tại
        MOV DL, snake[BX]      ; DL = ký tự của đoạn hiện tại ('O' hoặc 'o')
        ES: MOV [DI], DL       ; Ghi ký tự lên màn hình tại vị trí DI
        ADD SI, 2              ; Chuyển sang vị trí tiếp theo trong mảng position
        INC BX                 ; Chuyển sang ký tự tiếp theo trong mảng snake
        LOOP move_segments     ; Lặp lại cho đến hết chiều dài rắn
    
    ; Xóa ký tự ở vị trí cuối cùng (đuôi rắn cũ)
    MOV DI, position[SI] 
    ES: MOV [DI], 0
    RET
move_snake ENDP

border PROC ; Draw game border
    MOV AH, 0
    MOV AL, 3
    INT 10h  ; Set 80x25 text mode
    
    MOV AH, 6
    MOV AL, 0 
    MOV BH, 0ffh ; Border color
    
    MOV CH, 1
    MOV CL, 0
    MOV DH, 1
    MOV DL, 79
    INT 10h ; Top border
  
    MOV CH, 1
    MOV CL, 0
    MOV DH, 24
    MOV DL, 0
    INT 10h ; Left border
   
    MOV CH, 24
    MOV CL, 0
    MOV DH, 24
    MOV DL, 79
    INT 10h ; Bottom border
    
    MOV CH, 1
    MOV CL, 79
    MOV DH, 24
    MOV DL, 79
    INT 10h ; Right border

    RET
ENDP


print_score PROC
    MOV AH, 2
    MOV DH, 0
    MOV DL, 0
    MOV BH, 0
    INT 10h ; di chuyen con tro ve vi tri (0, 0)
    
    MOV AH, 9
    LEA DX, scoreString 
    INT 21h ; In chuỗi "SCORE: " ra màn hình
    
    MOV AX, 0
    MOV AL, totalScore  ; Use totalScore for display
    MOV CX, 0
    MOV BX, 10
    PUSH_STACK: ; Chuyển số sang chuỗi 
        MOV DX, 0
        DIV BX
        INC CX
        PUSH DX
        CMP AX, 0
        JNE PUSH_STACK
        
    POP_STACK:
        POP AX  
        MOV DL, AL
        ADD DL, '0'
        MOV AH, 2
        INT 21h
        LOOP POP_STACK 
    RET
print_score ENDP 



restart PROC
    CALL clearall
    MOV snakeLen, 1
    MOV BX, start_position
    MOV position, BX  
    MOV snake[0], 'O'
    ; Don't reset the score for restart, keep accumulated score after 3 lives
    JMP start_again
ENDP


game_over PROC
    XOR AX, AX             ; xoá thanh ghi AX
    MOV AL, totalScore     ; lưu điểm vào thanh ghi AL để in ra màn hình
    MOV lives[BX+5], 0
    ; in lives của người chơi ra màn hình
    LEA SI, lives
    MOV DI, 130
    MOV CX, 9
    CALL livesDisplay
    
    ;hiển thị gameover
    MOV DI, (10*80+35)*2   ; tính vị trí in trên màn hình (hàng 10, cột 35)
    ; in chuỗi "Game Over" ra màn hình
    LEA SI, gameOver
    MOV CX, 9
    loop1:
        MOVSB 
        INC DI
        LOOP loop1
    
    
    ; hiển thị restart    
    MOV DI, (12*80+30)*2.   ; tính vị trí in trên màn hình (hàng 12, cột 30)
    ; in chuỗi "Restart ? (y / n)" ra màn hình
    LEA SI, endtxt
    MOV CX, 17
    loop2:
        MOVSB 
        INC DI
        LOOP loop2 
    
    ; đặt lại các hiển thị lives, livesleft, dộ dài snake để bắt đầu lượt chơi mới
    MOV lives[6], 3 
    MOV lives[7], 3
    MOV lives[8], 3
    MOV livesLeft, 3
    MOV snakeLen, 1
    
    option:         
        MOV AH, 7.          ; đọc một ký tự từ bàn phím nhưng không hiển thị lên màn hình
        INT 21h
        ; nhận được ký tự 'y' thì nhảy đến restart
        CMP AL, 'y'   
        JE restart_game
        ; nhận được ký tự 'n' thì nhảy đến start_new_game  
        CMP AL, 'n'
        JE start_new_game        
        ; nhận được bất kỳ ký tự nào khác thì quay về option hỏi laị người chơi
        JMP option
        
    restart_game:
        ; đặt lại totalScore = 0 và bắt đầu lượt chơi mới 
        MOV totalScore, 0
        JMP start_again
        
    start_new_game:
        ; đặt lại totalScore=0 và bắt đầu lại game từ bước nhập username
        MOV totalScore, 0
        CALL get_name        ; nhập username
        CALL main_menu       ; chuyển đến menu cài đặt lại mode game
        JMP start_again
ENDP

; Xoá toàn bộ vùng hiển thị
clearall PROC
    MOV AH, 6 ; Hàm 6 trong ngắt 10h: scroll up màn hình
    MOV AL, 0 ; bios xoá toàn bộ vùng chọn bằng ký tự rỗng
    MOV BH, 7 ; Đặt thuộc tính màu sau khi xoá vùng hiển thị: nền đen (0) và chữ xám sáng (7)
    
    MOV CX, 0 ; Bắt đầu từ vị trí góc trên bên trái (0,0)
    MOV DH, 24 
    MOV DL, 79 ; Kết thúc ở vị trí góc dưới bên phải (25,80)
    INT 10h ; thực hiện xoá
    RET
ENDP

; Settings menu
settings_menu PROC ; Hiển thị menu Settings
    CALL clearall
    
    ; Display title         ; Hiển thị tiêu đề menu
    MOV AH, 2               ; Hàm INT 10h chức năng 2: Đặt vị trí con trỏ
    MOV DH, 5               ; Dòng 5
    MOV DL, 35              ; Cột 35 
    MOV BH, 0               ; Trang video 0
    INT 10h                 ; Gọi ngắt BIOS
    
    MOV AH, 9               ; Hàm INT 21h chức năng 9: In chuỗi kết thúc bằng '$'
    LEA DX, settingsTitle   ; Nạp địa chỉ chuỗi tiêu đề vào DX 
    INT 21h                 ; Gọi ngắt DOS để in chuỗi
    
    ; Display difficulty option ; Hiển thị tuỳ chọn độ khó
    MOV AH, 2               ; Đặt vị trí con trỏ
    MOV DH, 8               ; Dòng 8
    MOV DL, 30              ; Cột 30
    INT 10h                 ; Gọi ngắt BIOS
    
    MOV AH, 9               ; In chuỗi kết thúc bằng '$'         
    LEA DX, difficultyOption; Nạp địa chỉ chuỗi "Difficult: " vào DX
    INT 21h                 ; Gọi ngắt DOS để in chuỗi
    
    ; Display current difficulty ; Hiển thị độ khó hiện tại
    MOV AH, 9               ; Hàm INT 21h chức năng 9: In chuỗi kết thúc bằng '$'
    CMP difficultyLevel, 1  
    JE show_easy            ; Nếu difficultyLevel = 1 --> Dễ
    CMP difficultyLevel, 2
    JE show_medium          ; Nếu difficultyLevel = 2 --> Trung bình
    JMP show_hard           ; Mặc định còn lại là khó
    
    show_easy:
        LEA DX, difficultyEasy   ; Nạp địa chỉ chuỗi 'Easy'
        INT 21h                  ; Gọi ngắt DOS để in chuỗi
        JMP show_controls        ; Nhảy sang chế độ show_controls
        
    show_medium:
        LEA DX, difficultyMedium ; Nạp địa chỉ chuỗi 'Medium'
        INT 21h                  ; Gọi ngắt DOS để in chuỗi
        JMP show_controls        ; Nhảy sang chế độ show_controls
        
    show_hard:
        LEA DX, difficultyHard   ; Nạp địa chỉ chuỗi 'Hard'
        INT 21h                  ; Gọi ngắt DOS để in chuỗi
    
    show_controls:
        ; Display controls info
        MOV AH, 2               ; Đặt vị trí con trỏ
        MOV DH, 10              ; Dòng 10
        MOV DL, 25              ; Cột 25
        INT 10h                 ; Gọi BIOS để di chuyển con trỏ đến vị trí (10, 25)
        
        MOV AH, 9               ; In ra chuỗi kết thúc bằng '$'
        LEA DX, controlsOption  ; Nạp địa chỉ chuỗi 'Controls: WASD to move, ESC for menu' vào thanh ghi DX
        INT 21h                 ; Gọi ngắt DOS để in chuỗi
        
        ; Display instructions
        MOV AH, 2               ; Đặt vị trí con trỏ
        MOV DH, 12              ; Dòng 12
        MOV DL, 25              ; Cột 25
        INT 10h                 ; Gọi BIOS để di chuyển con trỏ đến vị trí (12, 25)
        
        MOV AH, 9               ; In ra chuỗi kết thúc bằng '$'
        LEA DX, backOption      ; Nạp địa chỉ chuỗi vào thanh ghi DX
        INT 21h                 ; Gọi ngắt DOS để in chuỗi
        
        MOV AH, 2               
        MOV DH, 14
        MOV DL, 25
        INT 10h
        ; --> Di chuyển con trỏ đến vị trí (14, 25)             
        
        ; Display difficulty change option
        MOV AH, 9
        LEA DX, changeDiffOption
        INT 21h
        ; --> In ra nội dung chuỗi trong changeDiffOption

      settings_input:
        MOV AH, 0     ; Wait for keypress (blocking)
        INT 16h       ; Get keypress
        
        CMP AL, '1'   
        JE set_easy        ; Nếu AL = 1 nhảy sang chế độ set_easy
        
        CMP AL, '2'
        JE set_medium      ; Nếu AL = 2 nhảy sang chế độ set_medium
        
        CMP AL, '3'
        JE set_hard        ; Nếu AL = 3 nhảy sang chế độ set_hard
        
        CMP AL, 27          
        JE exit_settings   ; Nếu AL = 27 (người dùng nhấn ESC - ASCII = 27) thoát khỏi chế độ settings
        
        JMP settings_input ; Auto nhảy về lại setttings_input nếu người dùng không nhập lựa chọn nào ở trên
        
    set_easy:
        MOV difficultyLevel, 1 ; Gán độ khó = 1 (Easy)
        JMP settings_menu      ; Quay lại menu
        
    set_medium:
        MOV difficultyLevel, 2 ; Gán độ khó = 2 (Medium)
        JMP settings_menu      ; Quay lại menu
        
    set_hard:
        MOV difficultyLevel, 3 ; Gán độ khó = 3 (Hard)
        JMP settings_menu      ; Quay lại menu
        
    exit_settings:
        RET                    ; Kết thúc thủ tục và quay về chương trình gọi
settings_menu ENDP ; Kết thúc thủ tục settings_menu

; Delay based on difficulty level
delays PROC
    PUSH CX
    PUSH AX
    
    ; Check difficulty level
    CMP difficultyLevel, 1
    JE easy_delay
    CMP difficultyLevel, 2
    JE medium_delay
    JMP hard_delay
    
    easy_delay:
        MOV CX, 60
        JMP do_delay
        
    medium_delay:
        MOV CX, 30
        JMP do_delay
        
    hard_delay:
        MOV CX, 1
        
    do_delay:
        ; Simple delay loop
        LOOP do_delay
        
    POP AX
    POP CX
    RET
delays ENDP
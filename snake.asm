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
    MOV AX, @Data
    MOV DS, AX
    
    MOV AX, 0b800h
    MOV ES, AX 
    
    MOV AH, 0
    MOV AL, 3
    INT 10h ; Set 80x25 text mode
        
    ; DX commonly for position/location parameters
    ; CX commonly for counts, sizes, or characteristics
    MOV AH, 2
    MOV DH, 10
    MOV DL, 25
    INT 10h
    
    CALL get_name
    ; hide text cursor
    MOV AH, 1
    MOV CH, 2BH
    MOV CL, 0BH
    INT 10h    
    CALL main_menu

start_again:
    CALL clearall
    MOV position, start_position ; Reset snake position
    CALL draw    
    XOR CL, CL 
    XOR DL, DL ; Clear input buffer
    MOV DL, 'D' ; Default direction right

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

; Get player name from user input
get_name PROC
    CALL clearall

    ; Display name prompt
    prompt:
        MOV AH, 2
        MOV DH, 10
        MOV DL, 25
        MOV BH, 0
        INT 10h
        ; Display name prompt    
        MOV AH, 9
        LEA DX, namePrompt
        INT 21h

    ; Get name input (max 15 chars)
    XOR CX, CX
    XOR SI, SI ; SI will be our index register
    input_loop:
        MOV AH, 1
        INT 21h

        CMP AL, 8 ; Backspace
        JE delete_char
        
        CMP AL, 13 ; Check for Enter key
        JE end_input
        
        CMP CL, 15 ; Max name length
        JE input_loop
        
        MOV playerName[SI], AL ; Use SI for indexing
        INC SI
        INC CL
        JMP input_loop

    delete_char:
        DEC SI
        DEC CL
        CMP SI, 0 ; Don't go below 0
        JE input_loop
        JMP prompt
        
    end_input:
        MOV nameLen, CL
        ; Make sure the name is terminated properly
        MOV playerName[SI], '$'
        RET
get_name ENDP

; Display main menu with options
main_menu PROC
    CALL clearall
    
    ; Display SNAKE ascii art title
    ; REFERENCE
    MOV DI, (3*80+25)*2
    LEA SI, t0
    MOV CX, 31
    d0:
        MOVSB
        INC DI
        LOOP d0
    
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
    
    ; Display welcome message with player name
    MOV AH, 2
    MOV DH, 10 
    MOV DL, 25
    MOV BH, 0
    INT 10h
    
    MOV AH, 9
    LEA DX, welcome
    INT 21h
    
    MOV AH, 9
    LEA DX, playerName
    INT 21h
    
    ; Display menu options
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
    
    menu_select:
        MOV AH, 0
        INT 16h ; Wait for keypress
        
        CMP AL, '1'
        JE start_game
        
        CMP AL, '2'
        JE show_settings
        
        CMP AL, '3'
        JE exit_game

        JMP menu_select
        
    start_game:
        ; Reset totalScore for a brand new game
        MOV totalScore, 0
        RET
        
    show_settings:
        CALL settings_menu
        JMP main_menu
        
    exit_game:
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

eat_food PROC ; Check snake collisions with food, walls, and itself
    PUSH AX 
    PUSH CX 
    
    MOV DI, position 
    ES: CMP [DI], 0 
    JZ no
    ES: CMP [DI], 20h
    JZ wall
    ES: CMP [DI], '*'
    JE addfood
    ES: CMP [DI], '#'
    JE wallKnock ; Obstacle collision
    JNE wallKnock ; Self collision
    
    addfood:
        INC totalScore  ; Increment total score for accumulated scoring
        MOV foods, 0 
        XOR BH, BH
        MOV BL, snakeLen
        MOV snake[BX], 'o'
        ES: MOV [DI], 0
        ADD snakeLen, 1 
        CALL print_score
        CALL place_food
        JMP no
        
    wall: ; Wall collision check
        CMP DI, 320 
        JBE wallKnock ; Top wall
        CMP DI, 3840
        JAE wallKnock ; Bottom wall
        MOV AX, DI
        MOV BL, 160
        DIV BL
        CMP AH, 0
        JZ wallKnock ; Left wall
        MOV AX, DI
        ADD AX, 2
        MOV BL, 160
        DIV BL
        CMP AH, 0
        JZ wallKnock ; Right wall
        JMP no
        
    wallKnock: ; Handle collision
        XOR BH, BH
        MOV BL, livesLeft
        SUB livesLeft, 1
        CMP livesLeft, 0
        JNZ rest
        POP CX
        POP AX
        CALL game_over 
        
    rest: ; Restart with one less life
        MOV lives[BX+5], 0
        POP CX
        POP AX
        CALL restart
        
    no:
        POP CX
        POP AX
    RET
ENDP


place_food PROC ; Place food at random position
    PUSH AX
    PUSH DX
    
    lap:    
        MOV AH, 00h
        INT 1AH ; Get system time in DX (clock ticks since midnight)
        
        MOV AX, DX
        XOR DX, DX
        DIV map
        ADD DX, 2*(80*2 + 1) ; Inside the playable area
        MOV BX, DX 
        
        MOV AX, DX  
        XOR DX, DX
        DIV two
        CMP DX, 0
        JNE lap
        
    ; Check if food is at column boundary
    XOR DX, DX 
    MOV AX, BX
    DIV endline
    CMP DX, 0
    JE inleft
    
    XOR DX, DX    
    MOV AX, BX
    ADD AX, 4
    DIV endline
    CMP DX, 0
    JE inright

    inleft:
        ADD BX, 2
        JMP place
        
    inright:
        SUB BX, 2
        
    place:    
        ES: MOV [BX], '*'
        MOV foods, BX
        
    POP DX
    POP AX 
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
    INT 21h
    
    MOV AX, 0
    MOV AL, totalScore  ; Use totalScore for display
    MOV CX, 0
    MOV BX, 10
    PUSH_STACK:
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
    XOR AX, AX
    MOV AL, totalScore
    MOV lives[BX+5], 0
    LEA SI, lives
    MOV DI, 130
    MOV CX, 9
    CALL livesDisplay
    
    ; Display game over
    MOV DI, (10*80+35)*2
    LEA SI, gameOver
    MOV CX, 9
    loop1:
        MOVSB 
        INC DI
        LOOP loop1
    
    
    ; Display restart option    
    MOV DI, (12*80+30)*2
    LEA SI, endtxt
    MOV CX, 17
    loop2:
        MOVSB 
        INC DI
        LOOP loop2 
    
    ; Reset game stats for next game
    MOV lives[6], 3 
    MOV lives[7], 3
    MOV lives[8], 3
    MOV livesLeft, 3
    MOV snakeLen, 1
    
    option:         
        MOV AH, 7
        INT 21h
        CMP AL, 'y'   
        JE restart_game
        CMP AL, 'n'
        JE start_new_game        
        JMP option
        
    restart_game:
        ; Reset score but keep totalScore for accumulated score
        MOV totalScore, 0
        JMP start_again
        
    start_new_game:
        ; Reset score and start completely new game with new name
        MOV totalScore, 0
        CALL get_name
        CALL main_menu
        JMP start_again
ENDP

clearall PROC
    MOV AH, 6 ; Scroll up (clear) window
    MOV AL, 0 ; Clear entire window
    MOV BH, 7 ; black background + light gray text
    ; 80x25 window
    MOV CX, 0 ; Upper left corner (0,0)
    MOV DH, 24 ; Lower right row
    MOV DL, 79 ; Lower right column
    INT 10h
    RET
ENDP

; Settings menu
settings_menu PROC
    CALL clearall
    
    ; Display title
    MOV AH, 2
    MOV DH, 5
    MOV DL, 35
    MOV BH, 0
    INT 10h
    
    MOV AH, 9
    LEA DX, settingsTitle
    INT 21h
    
    ; Display difficulty option
    MOV AH, 2
    MOV DH, 8
    MOV DL, 30
    INT 10h
    
    MOV AH, 9
    LEA DX, difficultyOption
    INT 21h
    
    ; Display current difficulty
    MOV AH, 9
    CMP difficultyLevel, 1
    JE show_easy
    CMP difficultyLevel, 2
    JE show_medium
    JMP show_hard
    
    show_easy:
        LEA DX, difficultyEasy
        INT 21h
        JMP show_controls
        
    show_medium:
        LEA DX, difficultyMedium
        INT 21h
        JMP show_controls
        
    show_hard:
        LEA DX, difficultyHard
        INT 21h
    
    show_controls:
        ; Display controls info
        MOV AH, 2
        MOV DH, 10
        MOV DL, 25
        INT 10h
        
        MOV AH, 9
        LEA DX, controlsOption
        INT 21h
        
        ; Display instructions
        MOV AH, 2
        MOV DH, 12
        MOV DL, 25
        INT 10h
        
        MOV AH, 9
        LEA DX, backOption
        INT 21h
        
        MOV AH, 2
        MOV DH, 14
        MOV DL, 25
        INT 10h
        
        ; Display difficulty change option
        MOV AH, 9
        LEA DX, changeDiffOption
        INT 21h

      settings_input:
        MOV AH, 0     ; Wait for keypress (blocking)
        INT 16h       ; Get keypress
        
        CMP AL, '1'
        JE set_easy
        
        CMP AL, '2'
        JE set_medium
        
        CMP AL, '3'
        JE set_hard
        
        CMP AL, 27 ; ESC key
        JE exit_settings
        
        JMP settings_input
        
    set_easy:
        MOV difficultyLevel, 1
        JMP settings_menu
        
    set_medium:
        MOV difficultyLevel, 2
        JMP settings_menu
        
    set_hard:
        MOV difficultyLevel, 3
        JMP settings_menu
        
    exit_settings:
        RET
settings_menu ENDP

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
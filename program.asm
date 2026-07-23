BITS 16                             ; 16-bit real mode code (typical for a BIOS/boot-sector program)
ORG 0x8400                          ; program is loaded at 0x8400 -> addresses are computed accordingly

MAX_LENGTH equ 640                  ; maximum snake length (number of possible segments)

; Data: snake position arrays
snake_x:      times MAX_LENGTH dw 0 ; X coordinate of every segment, index 0 = head
snake_y:      times MAX_LENGTH dw 0 ; Y coordinate of every segment, index 0 = head
snake_length: dw 1                  ; current snake length (number of entries in use above)

apple_x:      dw 150                ; apple X position
apple_y:      dw 100                ; apple Y position
draw_color:   db 13                 ; current drawing color (set before every draw_square call)

; Entry point / (re-)initialization
main:
    ; set graphics mode: mode 0x13 = 320x200, 256 colors (VGA)
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    ; reset game state
    ; main is also re-entered whenever menu.asm jumps back here with
    ; "jmp 0x8400", so all state needs to be reset every time.
    mov word [snake_length], 1      ; snake starts with just the head
    mov word [snake_x], 160         ; head start position: X
    mov word [snake_y], 160         ; head start position: Y

    mov word [move_x], 10           ; movement direction: right by default
    mov word [move_y], 0

    call spawn_apple                ; place the first apple

; Main game loop: runs forever, one pass = one tick
game_loop:
    call clear_screen                ; paint the whole screen green (clear)
    call draw_snake                  ; draw every snake segment

    mov byte [draw_color], 4         ; red for the apple
    mov si, [apple_y]                ; draw_square expects Y in si
    mov bp, [apple_x]                ; draw_square expects X in bp
    call draw_square                 ; draw the apple as a square

    call wait_one_second              ; wait ~1 second, polling keys the whole time

    call move_snake                   ; shift the body, then update the head (apply movement)

    ; self-collision: does the head touch the body?
    mov ax, [snake_x]
    mov dx, [snake_y]
    call check_collision              ; sets carry flag if the head hits a body segment
    jc game_over

    ; clamp head position (snake_x[0]/snake_y[0]) to the screen edges
    ; touching an edge also ends the game (jumps to game_over below)
    mov ax, [snake_y]
    cmp ax, 190                       ; bottom edge (200 screen height - 10px square size)
    jle .y_ok
    mov word [snake_y], 190
    jmp game_over
.y_ok:
    mov ax, [snake_y]
    cmp ax, 0                         ; top edge
    jge .y_ok2
    mov word [snake_y], 0
    jmp game_over
.y_ok2:

    mov ax, [snake_x]
    cmp ax, 310                       ; right edge (320 screen width - 10px)
    jle .x_ok
    mov word [snake_x], 310
    jmp game_over
.x_ok:
    mov ax, [snake_x]
    cmp ax, 0                         ; left edge
    jge .x_ok2
    mov word [snake_x], 0
    jmp game_over
.x_ok2:

    ; did the snake eat the apple? compare head position to apple position
    mov ax, [snake_x]
    cmp ax, [apple_x]
    jne .no_apple                     ; X doesn't match -> no hit
    mov ax, [snake_y]
    cmp ax, [apple_y]
    jne .no_apple                     ; Y doesn't match -> no hit

    ; THIS is where the snake grows
    ; Apple eaten: increase length (if there's room) and spawn a new apple.
    ; A "new segment" isn't created by adding a new entry, instead
    ; snake_length is incremented, so draw_snake now draws one more
    ; segment and move_snake shifts one element further, activating
    ; the previously unused array slot at index [old_snake_length].
    cmp word [snake_length], MAX_LENGTH
    jge .no_apple                     ; already at max length -> don't grow further
    inc word [snake_length]           ; <<< the snake grows by one segment here
    call spawn_apple                  ; place a new apple at a random position

.no_apple:
    jmp game_loop                     ; next round (infinite loop)

; Clear the screen: set every pixel of the 320x200 screen to color 2 (green)
clear_screen:
    mov ax, 0xA000                   ; segment of VGA video memory (mode 0x13)
    mov es, ax

    mov dx, 0                        ; dx = current row (y)
.clear_outer:
    mov cx, 0                        ; cx = current column (x)
.clear_inner:
    push dx
    push cx
    mov ax, dx
    mov bx, 320                      ; screen width
    mul bx                           ; ax = y * 320 (offset of the row start)
    pop cx
    add ax, cx                       ; ax = y*320 + x (linear pixel offset)
    mov di, ax
    mov byte [es:di], 2              ; set pixel to color 2 (green)
    pop dx

    inc cx
    cmp cx, 320
    jl .clear_inner                   ; column loop up to x=320

    inc dx
    cmp dx, 200
    jl .clear_outer                   ; row loop up to y=200
    ret

; Sets apple_x/apple_y to a pseudo-random, grid-aligned position
; (grid: 32 columns x 20 rows, 10px each)
spawn_apple:
    push ax
    push bx
    push cx
    push dx
    push si

    xor ah, ah
    int 0x1A                         ; BIOS: cx:dx = tick count since midnight (used as random seed)
    mov bx, dx                       ; first seed (for x)
    mov ax, cx
    xor ax, dx
    mov si, ax                       ; second seed (for y), combined from cx and dx

    ; x = (bx mod 32) * 10   (32 is a power of two -> AND is enough)
    mov ax, bx
    and ax, 0x1F                     ; ax mod 32
    mov cx, 10
    mul cx                           ; ax = (ax mod 32) * 10
    mov [apple_x], ax

    ; y = (si mod 20) * 10   (20 is not a power of two -> DIV needed)
    mov ax, si
    xor dx, dx
    mov cx, 20
    div cx                            ; ax = si/20, dx = remainder (0..19) -> that's the modulo
    mov ax, dx
    mov cx, 10
    mul cx                            ; ax = (si mod 20) * 10
    mov [apple_y], ax

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Move the snake: shift the body (each segment moves to the
; position of its predecessor), then recompute the head
move_snake:
    push ax
    push bx
    push cx
    push di

    mov cx, [snake_length]
    dec cx                            ; cx = index of the last segment (snake_length - 1)
    cmp cx, 0
    jle .move_head                     ; only 1 segment (head only) -> nothing to shift

.shift_loop:
    ; segment[cx] = segment[cx-1]   (back to front, so nothing gets
    ; overwritten before it has been copied)
    mov bx, cx
    dec bx
    shl bx, 1                         ; bx = (cx-1) * 2   (word index -> byte offset)
    mov di, cx
    shl di, 1                         ; di = cx * 2

    mov ax, [snake_x + bx]
    mov [snake_x + di], ax
    mov ax, [snake_y + bx]
    mov [snake_y + di], ax

    dec cx
    jnz .shift_loop                    ; count down until segment 1 is copied (index 0 stays for the head)

.move_head:
    ; move the head (index 0) by the current movement direction
    mov ax, [snake_x]
    add ax, [move_x]
    mov [snake_x], ax

    mov ax, [snake_y]
    add ax, [move_y]
    mov [snake_y], ax

    pop di
    pop cx
    pop bx
    pop ax
    ret

; Draw every snake segment (index 0 to snake_length-1)
draw_snake:
    push cx
    mov cx, 0                         ; loop counter = current segment

.draw_loop:
    push cx
    mov bx, cx
    shl bx, 1                         ; bx = byte offset of this segment in the array
    mov si, [snake_y + bx]            ; Y position of this segment
    mov bp, [snake_x + bx]            ; X position of this segment

    mov byte [draw_color], 13         ; pink for snake segments
    call draw_square

    pop cx
    inc cx
    cmp cx, [snake_length]            ; keep going until every segment is drawn
    jl .draw_loop

    pop cx
    ret

; Draws a 10x10 square at position (bp, si) in color [draw_color]
draw_square:
    push ax
    push bx
    push cx
    push dx
    push di

    mov ax, 0xA000
    mov es, ax

    mov dx, 0                         ; dx = row inside the square (0..9)
.outer:
    mov cx, 0                         ; cx = column inside the square (0..9)
.inner:
    push dx
    push cx
    mov ax, dx
    add ax, si                        ; ax = si (base Y) + local row
    mov bx, 320
    mul bx                            ; ax = (Y position) * 320
    pop cx
    add ax, cx                        ; + local column
    add ax, bp                        ; + base X (bp)
    mov di, ax                        ; di = linear pixel offset in video memory
    mov al, [draw_color]
    mov [es:di], al                   ; set the pixel
    pop dx

    inc cx
    cmp cx, 10
    jl .inner                          ; 10 columns per row

    inc dx
    cmp dx, 10
    jl .outer                          ; 10 rows total -> 10x10 square

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Waits about 1 second (18 BIOS timer ticks ~ 1s) while
; continuously polling for keyboard input to change direction
wait_one_second:
    push ax
    push bx
    push cx
    push dx

    xor ah, ah
    int 0x1A                          ; get the current tick count (start time)
    mov bx, dx                        ; bx = starting tick value

.wait_loop:
    mov ah, 0x01                      ; BIOS: check if a key is waiting (without removing it)
    int 0x16
    jz .no_key                        ; ZF set -> no key pressed

    mov ah, 0x00                      ; BIOS: actually read the key (removes it from the buffer)
    int 0x16

    cmp ah, 0x48                      ; scancode: arrow up
    jne .check_down
    mov word [move_x], 0
    mov word [move_y], -10
    jmp .no_key
.check_down:
    cmp ah, 0x50                      ; scancode: arrow down
    jne .check_left
    mov word [move_x], 0
    mov word [move_y], 10
    jmp .no_key
.check_left:
    cmp ah, 0x4B                      ; scancode: arrow left
    jne .check_right
    mov word [move_x], -10
    mov word [move_y], 0
    jmp .no_key
.check_right:
    cmp ah, 0x4D                      ; scancode: arrow right
    jne .no_key
    mov word [move_x], 10
    mov word [move_y], 0

.no_key:
    xor ah, ah
    int 0x1A                          ; get the current tick count again
    sub dx, bx                        ; dx = ticks elapsed since start
    cmp dx, 18                        ; ~18 ticks is about 1 second (BIOS timer runs at ~18.2 Hz)
    jl .wait_loop                      ; not enough time has passed yet -> keep polling/waiting

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Collision check: does position (ax=X, dx=Y) match any body
; segment (index 1 upward, i.e. skipping the head itself)?
; Returns: carry flag (CF) = 1 -> collision found, CF = 0 -> no collision.
; (POP does not affect flags, so CF survives the pop instructions until ret.)
check_collision:
    push cx
    push bx
    mov cx, 1                         ; start at segment 1 (0 is the head itself, no point checking it)

.check_loop:
    mov bx, cx
    shl bx, 1                         ; byte offset of this segment
    cmp ax, [snake_x + bx]
    jne .no_hit
    cmp dx, [snake_y + bx]
    je .collision                     ; X and Y match -> collision found

.no_hit:
    inc cx
    cmp cx, [snake_length]
    jl .check_loop                     ; check every segment

    clc                                ; no collision found -> CF = 0
    pop bx
    pop cx
    ret

.collision:
    stc                                ; collision found -> CF = 1
    pop bx
    pop cx
    ret

; Movement direction, updated by keyboard input in wait_one_second
move_x: dw 0                          ; current per-tick movement in X direction (+10, -10 or 0)
move_y: dw 0                          ; current per-tick movement in Y direction (+10, -10 or 0)

; Snake died (hit an edge or itself) -> back to the menu.
; No memory needs to be freed since nothing is dynamically allocated.
; Resetting the state (snake_length, head position, ...) happens
; centrally at the top of main, once menu.asm sends us back here
; via "jmp 0x8400".
game_over:
    jmp 0x8000                        ; back to menu.asm (ORG 0x8000); a near jmp is enough,
                                       ; exactly like menu.asm does the reverse with "jmp 0x8400"

halt:
    jmp $                             ; infinite loop (halts the program, if ever reached)

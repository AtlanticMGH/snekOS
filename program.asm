BITS 16
ORG 0x8400

MAX_LENGTH equ 640

snake_x: times MAX_LENGTH dw 0
snake_y: times MAX_LENGTH dw 0
snake_length: dw 1

apple_x: dw 150
apple_y: dw 100
draw_color: db 13

main:
    ; Grafikmodus
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    mov word [move_x], 10       ; Bewegungsrichtung: standardmäßig nach rechts
    mov word [move_y], 0

    call spawn_apple            ; ersten Apfel platzieren

game_loop:
    call clear_screen
    call draw_snake

    mov byte [draw_color], 4    ; rot für den Apfel
    mov si, [apple_y]
    mov bp, [apple_x]
    call draw_square

    call wait_one_second        ; wartet ~1 Sekunde, fragt dabei Tasten ab

    call move_snake              ; Körper verschieben, Kopf neu setzen

    ; --- Kopf-Position (snake_x[0]/snake_y[0]) begrenzen ---
    mov ax, [snake_y]
    cmp ax, 190
    jle .y_ok
    mov word [snake_y], 190
.y_ok:
    mov ax, [snake_y]
    cmp ax, 0
    jge .y_ok2
    mov word [snake_y], 0
.y_ok2:

    mov ax, [snake_x]
    cmp ax, 310
    jle .x_ok
    mov word [snake_x], 310
.x_ok:
    mov ax, [snake_x]
    cmp ax, 0
    jge .x_ok2
    mov word [snake_x], 0
.x_ok2:

    ; --- Apfel gegessen? Kopf-Position mit Apfel-Position vergleichen ---
    mov ax, [snake_x]
    cmp ax, [apple_x]
    jne .no_apple
    mov ax, [snake_y]
    cmp ax, [apple_y]
    jne .no_apple

    ; Apfel gegessen: Länge erhöhen (falls Platz) und neuen Apfel setzen
    cmp word [snake_length], MAX_LENGTH
    jge .no_apple
    inc word [snake_length]
    call spawn_apple

.no_apple:
    jmp game_loop

clear_screen:
    mov ax, 0xA000
    mov es, ax

    mov dx, 0
.clear_outer:
    mov cx, 0
.clear_inner:
    push dx
    push cx
    mov ax, dx
    mov bx, 320
    mul bx
    pop cx
    add ax, cx
    mov di, ax
    mov byte [es:di], 2         ; grün
    pop dx

    inc cx
    cmp cx, 320
    jl .clear_inner

    inc dx
    cmp dx, 200
    jl .clear_outer
    ret

; Setzt apple_x/apple_y auf eine pseudozufällige, rasterausgerichtete Position
; (Raster: 32 Spalten x 20 Zeilen, je 10px)
spawn_apple:
    push ax
    push bx
    push cx
    push dx
    push si

    xor ah, ah
    int 0x1A                    ; cx:dx = Tickzähler seit Mitternacht
    mov bx, dx                  ; erster Seed (für x)
    mov ax, cx
    xor ax, dx
    mov si, ax                  ; zweiter Seed (für y)

    ; x = (bx mod 32) * 10   (32 ist Zweierpotenz -> AND reicht)
    mov ax, bx
    and ax, 0x1F
    mov cx, 10
    mul cx
    mov [apple_x], ax

    ; y = (si mod 20) * 10   (20 ist keine Zweierpotenz -> DIV nötig)
    mov ax, si
    xor dx, dx
    mov cx, 20
    div cx                       ; dx = Rest (0..19)
    mov ax, dx
    mov cx, 10
    mul cx
    mov [apple_y], ax

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

move_snake:
    push ax
    push bx
    push cx
    push di

    mov cx, [snake_length]
    dec cx
    cmp cx, 0
    jle .move_head

.shift_loop:
    mov bx, cx
    dec bx
    shl bx, 1
    mov di, cx
    shl di, 1

    mov ax, [snake_x + bx]
    mov [snake_x + di], ax
    mov ax, [snake_y + bx]
    mov [snake_y + di], ax

    dec cx
    jnz .shift_loop

.move_head:
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

draw_snake:
    push cx
    mov cx, 0

.draw_loop:
    push cx
    mov bx, cx
    shl bx, 1
    mov si, [snake_y + bx]
    mov bp, [snake_x + bx]

    mov byte [draw_color], 13   ; pink für Schlangensegmente
    call draw_square

    pop cx
    inc cx
    cmp cx, [snake_length]
    jl .draw_loop

    pop cx
    ret

; Zeichnet ein 10x10-Quadrat an Position (bp, si) in Farbe [draw_color]
draw_square:
    push ax
    push bx
    push cx
    push dx
    push di

    mov ax, 0xA000
    mov es, ax

    mov dx, 0
.outer:
    mov cx, 0
.inner:
    push dx
    push cx
    mov ax, dx
    add ax, si
    mov bx, 320
    mul bx
    pop cx
    add ax, cx
    add ax, bp
    mov di, ax
    mov al, [draw_color]
    mov [es:di], al
    pop dx

    inc cx
    cmp cx, 10
    jl .inner

    inc dx
    cmp dx, 10
    jl .outer

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

wait_one_second:
    push ax
    push bx
    push cx
    push dx

    xor ah, ah
    int 0x1A
    mov bx, dx

.wait_loop:
    mov ah, 0x01
    int 0x16
    jz .no_key

    mov ah, 0x00
    int 0x16

    cmp ah, 0x48
    jne .check_down
    mov word [move_x], 0
    mov word [move_y], -10
    jmp .no_key
.check_down:
    cmp ah, 0x50
    jne .check_left
    mov word [move_x], 0
    mov word [move_y], 10
    jmp .no_key
.check_left:
    cmp ah, 0x4B
    jne .check_right
    mov word [move_x], -10
    mov word [move_y], 0
    jmp .no_key
.check_right:
    cmp ah, 0x4D
    jne .no_key
    mov word [move_x], 10
    mov word [move_y], 0

.no_key:
    xor ah, ah
    int 0x1A
    sub dx, bx
    cmp dx, 18
    jl .wait_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

check_collision:
    push cx
    push bx
    mov cx, 1

.check_loop:
    mov bx, cx
    shl bx, 1
    cmp ax, [snake_x + bx]
    jne .no_hit
    cmp dx, [snake_y + bx]
    je .collision

.no_hit:
    inc cx
    cmp cx, [snake_length]
    jl .check_loop

    pop bx
    pop cx
    ret

.collision:
    pop bx
    pop cx
    ret

;-------------------------------------------
move_x: dw 0
move_y: dw 0

halt:
    jmp $

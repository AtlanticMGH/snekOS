BITS 16
ORG 0x8000

main:
    ; Grafikmodus
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    mov si, 0                   ; y position der schlange
    mov bp, 0                   ; x position der schlange
    mov word [move_x], 10       ; Bewegungsrichtung: standardmäßig nach rechts
    mov word [move_y], 0

game_loop:
    call clear_screen
    call draw_snake
    call wait_one_second   ; wartet ~1 Sekunde, fragt dabei Tasten ab

    ; Position nach der Wartezeit aktualisieren
    mov ax, [move_x]
    add bp, ax
    mov ax, [move_y]
    add si, ax

    jmp game_loop

clear_screen:
     ; Framebuffer
    mov ax, 0xA000
    mov es, ax

     ; 10x10 pinkes Rechteck
    mov dx, 0          ; y = 0
.clear_outer:
    mov cx, 0           ; x = 0
.clear_inner:
    ; Offset = y*320 + x
    ; Offset, da Framebuffer 1D array und es als konvertierung zum zeichnen genutzt wird
    push dx                     ; Register sichern
    push cx
    mov ax, dx
    mov bx, 320
    mul bx                      ; ax = y * 320
    pop cx
    add ax, cx                  ; ax = y*320 + x
    mov di, ax
    mov byte [es:di], 2         ; grün
    pop dx                      ; Register wiederherstellen

    inc cx
    cmp cx, 320
    jl .clear_inner

    inc dx
    cmp dx, 200
    jl .clear_outer
    ret


draw_snake:
    ; Framebuffer
    ;; mov ax, 0xA000
    ;; mov es, ax

    ; 10x10 pinkes Rechteck
    mov dx, 0          ; y = 0
.outer:
    mov cx, 0           ; x = 0
.inner:
    ; Offset = y*320 + x
    ; Offset, da Framebuffer 1D array und es als konvertierung zum zeichnen genutzt wird
    push dx                     ; Register sichern
    push cx
    mov ax, dx
    add ax, si                  ; y wert drauf addieren, damit die position geändert wird
    mov bx, 320
    mul bx                      ; ax = y * 320
    pop cx
    add ax, cx                  ; ax = y*320 + x
    add ax, bp                  ; x wert drauf addieren
    mov di, ax
    mov byte [es:di], 13        ; pink
    pop dx                      ; Register wiederherstellen

    inc cx
    cmp cx, 10
    jl .inner

    inc dx
    cmp dx, 10
    jl .outer

    ret

; Wartet ca. 1 Sekunde (18 Ticks), fragt dabei laufend Tasten ab
wait_one_second:
    push ax
    push bx
    push cx
    push dx

    xor ah, ah
    int 0x1A                    ; CX:DX = aktueller Tickzähler
    mov bx, dx                  ; Startwert merken (nur unteres Wort reicht meist)

.wait_loop:
    ; --- Taste abfragen, ohne zu blockieren ---
    mov ah, 0x01
    int 0x16
    jz .no_key                  ; keine Taste da -> weiter warten

    mov ah, 0x00                ; Taste vorhanden -> auslesen (aus Puffer entfernen)
    int 0x16

    cmp ah, 0x48                ; Pfeil hoch
    jne .check_down
    mov word [move_x], 0
    mov word [move_y], -10
    jmp .no_key
.check_down:
    cmp ah, 0x50                ; Pfeil runter
    jne .check_left
    mov word [move_x], 0
    mov word [move_y], 10
    jmp .no_key
.check_left:
    cmp ah, 0x4B                ; Pfeil links
    jne .check_right
    mov word [move_x], -10
    mov word [move_y], 0
    jmp .no_key
.check_right:
    cmp ah, 0x4D                ; Pfeil rechts
    jne .no_key
    mov word [move_x], 10
    mov word [move_y], 0

.no_key:
    ; --- Prüfen, ob genug Zeit vergangen ist ---
    xor ah, ah
    int 0x1A
    sub dx, bx
    cmp dx, 18                  ; ~1 Sekunde vergangen?
    jl .wait_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

;-------------------------------------------
move_x: dw 0
move_y: dw 0

halt:
    jmp $

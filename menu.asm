BITS 16
ORG 0x8000

main:
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov ah, 0x13
    mov al, 0x01
    mov bh, 0
    mov bl, 0x0A
    mov cx, 5
    mov dh, 10
    mov dl, 37
    push cs
    pop es
    mov bp, snake
    int 0x10

wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    jne wait_key

    ; kurz warten
    mov cx, 0xFFFF
.warte:
    loop .warte

    jmp 0x8400

snake db "Snake"

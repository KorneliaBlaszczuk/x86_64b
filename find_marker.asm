;---------------------------------------------
; Author: Kornelia Błaszczuk
; Project: Finding marker (no. 3)
;---------------------------------------------

; BMP INFO
BMP_FORMAT      equ     19778   ; Id of BMP format
RESULT_S        equ     200

; Constants for BMP header offsets
HEIGHT_OFFSET   equ 22   ; Offset of height field in BMP header (in bytes)
WIDTH_OFFSET    equ 18   ; Offset of width field in BMP header (in bytes)

section .bss
    result_buffer:  resb    RESULT_S
    HEIGHT_VALUE    resq 1   ; Reserve space to store the height value (quadword for 64-bit)
    WIDTH_VALUE     resq 1   ; Reserve space to store the width value (quadword for 64-bit)
    PIXEL_ARRAY_SIZE resq 1  ; Reserve space to store the pixel array size (quadword for 64-bit)
    BYTES_PER_ROW   resq 1  ; Reserve space to store bytes per row (quadword for 64-bit)

section .text
    global  find_marker

find_marker:
    push    rsi
    push    rbp
    mov     rbp,    rsp

    sub     rsp, 32        ; Space for local variables
    mov     QWORD [rbp-8], rdi   ; Store memblock in local variable
    mov     QWORD [rbp-16], rsi  ; Store x_pos array start address
    mov     QWORD [rbp-24], rdx  ; Store y_pos array start address


.analyze_header:
    ; Analyze header -> checks if the file is in bmp format
    push  rax                   ;rax = file start
    mov rax, rdi
    mov   ax,  WORD[rax]        ;rax = file header
    cmp   ax,  BMP_FORMAT         ;copmare with known bmp header
    jne   .wrong_file_format

    ; Read the width from the BMP header
    mov rax, QWORD[rbp-8]
    add rax, WIDTH_OFFSET        ; Offset to the width field
    movzx rbx, WORD [rax]        ; Load the width value (using WORD to load 16 bits)
    mov [WIDTH_VALUE], rbx       ; Store the width value

    ; Read the height from the BMP header
    ;mov rax, QWORD[rbp+16]       ; Load the address of the BMP header
    mov rax, QWORD[rbp-8]
    add rax, HEIGHT_OFFSET       ; Offset to the height field
    movzx rbx, WORD [rax]        ; Load the height value (using WORD to load 16 bits)
    mov [HEIGHT_VALUE], rbx      ; Store the height value

    ; Calculate the bytes per row based on the width and bytes per pixel
    mov rax, [WIDTH_VALUE]       ; Load the width value
    imul rax, 3                   ; Multiply by bytes per pixel (assuming 24 bits per pixel)
    add rax, 3                    ; Add 3 to round up to the nearest multiple of 4
    shr rax, 2                    ; Divide by 4 to get the number of DWORDs (32-bit words)
    shl rax, 2                    ; Multiply by 4 to get the number of bytes per row
    mov [BYTES_PER_ROW], rax     ; Store the result as bytes per row

    ; Calculate the total size of the pixel array including row padding
    mov     rax, [BYTES_PER_ROW]     ; Load the bytes per row
    imul    rax, [HEIGHT_VALUE]      ; Multiply by the height
    mov     [PIXEL_ARRAY_SIZE], rax  ; Store the result as the total size of the pixel

    jmp .get_variables

.get_variables:
    mov   rax,  QWORD[rbp-8]    ;rax = file start
    mov   rsi,  0
    mov   esi,  DWORD[rax+10]
    add   rax,  rsi
    mov   QWORD[rbp-8], rax
    mov   rax,  QWORD[rbp-8]
    mov rbx, [PIXEL_ARRAY_SIZE]
    add   rax,  rbx        ;rax = pixel array end
    push  rax                   ;push rax
    mov     QWORD[rbp-120],   rax

    sub     rsp,    80

    mov     QWORD[rbp-88], 0
    mov     QWORD[rbp-128],      0
    mov     QWORD[rbp-72],      result_buffer   ; result iterator
    mov     QWORD[rbp-112],      0

    ;   [rbp-8]  -> pixel array start
    ;   [rbp-16] -> x_pos
    ;   [rbp-24] -> y_pos
    ;   [rbp-32] -> current color
    ;   [rbp-40] -> thickness_height
    ;   [rbp-48] -> height
    ;   [rbp-56] -> width
    ;   [rbp-64] -> thickness_width
    ;   [rbp-72] -> result iterator
    ;   [rbp-80] -> pixel after marker
    ;   [rbp-88] -> store stage: so the get_pixel knows where to return
    ;   [rbp-96] -> first column iterator
    ;   [rbp-104] -> second height iterator
    ;   [rbp-112] -> counter for finding markers

    ; [rbp-120] -> pixel array end
    ; [rbp-128] -> point where arms cross

.analyze_pixels:
    mov     rsi,    QWORD[rbp-8]    ; array iterator
    jmp     .next_black

    .next_marker:
        mov     rsi,    QWORD[rbp-80]
        jmp     .next_black

    ; stage 0
    .next_black:
        ; Check if end of pixel array
        cmp     rsi,    QWORD[rbp-120]
        jge     .find_marker_end

        ; Move esi into rax
        mov     rax,    rsi

        ; Get pixel color
        jmp     .get_pixel_color

    .next_black_continue:

        ; if not black go to next pixel
        cmp     QWORD[rbp-32],    0
        jne     .next

        mov     QWORD[rbp-128],  rsi
        mov     QWORD[rbp-48],  3     ; height
        mov     QWORD[rbp-88],  1     ; stage

        jmp     .height

    .next:
        add     rsi,    3
        jmp     .next_black

    ; stage 1
    .height:
        mov     rax,    rsi
        mov     rbx,    [BYTES_PER_ROW]    ; go row up
        add     rax,    rbx
        cmp     rax,    QWORD[rbp-120]      ; if end of pixel array -> end of count
        jge     .height_end

        jmp     .get_pixel_color

    .height_continue:
        cmp     QWORD[rbp-32],  0
        jne     .height_end

        add     QWORD[rbp-48],  3
        mov     rbx,    [BYTES_PER_ROW]
        add     rsi,    rbx                ; row up
        jmp     .height

    .height_end:
        mov     QWORD[rbp-40],  3          ; thickness_height
        mov     QWORD[rbp-88],  2          ; stage
        jmp     .thick

    ; stage 2
    .thick:
        mov     rax,    rsi
        add     rax,    3
        cmp     rax,    QWORD[rbp-120]      ; if end of pixel array -> end of count
        jge     .thick_end

        jmp     .get_pixel_color

    .thick_continue:
        cmp     QWORD[rbp-32],  0          ; if not black check next parameter
        jne     .thick_end

        add     QWORD[rbp-40],    3        ; stage
        add     rsi,    3
        jmp     .thick

    .thick_end:
        mov     QWORD[rbp-56],    3        ; width
        mov     rsi,    QWORD[rbp-128]      ; start from the point where the arms cross
        mov     QWORD[rbp-88], 3

        jmp     .width

    ; stage 3
    .width:
        ; checking if last pixel in row
        mov     rax,    rsi
        mov     rbx,    [BYTES_PER_ROW]
        add     rax,    rbx               ; rax - address of the pixel
        sub     rax,    QWORD[rbp-8]      ; rax -= array start
        xor     rdx,    rdx               ; rdx = 0
        mov     rcx,    rbx
        div     rcx

        mov     rax,    rdx
        xor     rdx,    rdx
        mov     rcx,    3
        div     rcx
        mov     rbx,    [WIDTH_VALUE]
        dec     rbx                       ; rbx = [WIDTH_VALUE] - 1
        cmp     rbx,    rax               ; check if last in row (coords starts from 0)
        je      .check
        ;--------------------------

        mov     rax,    rsi
        add     rax,    3
        cmp     rax,    QWORD[rbp-120]     ; check if end of pixel array
        jge     .check

        jmp     .get_pixel_color

    .width_continue:
        cmp     QWORD[rbp-32],  0
        jne     .check

        add     QWORD[rbp-56],  3
        add     rsi,    3
        jmp     .width

    .check:
        mov     rdx,  rsi                ; Use rdx instead of ecx for address calculation
        add     rdx,    3
        mov     QWORD[rbp-80],  rdx
        mov     rcx,    QWORD[rbp-56]    ; width

        cmp     rcx,    QWORD[rbp-48]    ; cmp width and height
        jne     .go_to_next_marker

        cmp     rcx,    QWORD[rbp-40]    ; cmp width and thickness_height
        je      .go_to_next_marker

        mov     QWORD[rbp-64],  3        ; thickness_width

        sub     rsi,    3                ; go to the last pixel in marker

        jmp     .thickness_width
    ; stage 4
    .thickness_width:
        mov     rax,    rsi
        mov     rbx,    [BYTES_PER_ROW]
        add     rax,    rbx
        cmp     rax,    QWORD[rbp-120]
        jge     .thickness_width_end

        mov     QWORD[rbp-88],  4        ; stage
        jmp     .get_pixel_color

    .thickness_width_continue:
        cmp     QWORD[rbp-32],  0
        jne     .thickness_width_end

        add     QWORD[rbp-64],    3
        mov     rbx,    [BYTES_PER_ROW] ; go row up
        add     rsi,    rbx
        jmp     .thickness_width

    .thickness_width_end:
        mov     rsi,    QWORD[rbp-80]    ; pixel after marker
        jmp     .check_inside


    .check_inside:
        mov     rsi,    QWORD[rbp-128]    ; Load the start of the pixel array
        mov     rdi,    QWORD[rbp-128]    ; Load the start of the pixel array
        mov     QWORD[rbp-104],  3       ; width
        mov     QWORD[rbp-96],   3       ; height

        jmp     .loop_1                  ; Jump to the loop

        .loop_1:
            mov     rax,    rsi
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx
            cmp     rax,    QWORD[rbp-120]
            jge     .next_loop

            mov     QWORD[rbp-88],  5        ; stage
            jmp     .get_pixel_color

        .loop_continue:
            cmp     QWORD[rbp-32],  0
            jne     .next_loop

            add     QWORD[rbp-96],    3     ; first iterator - column
            mov     rbx,    [BYTES_PER_ROW] ; row up
            add     rsi,    rbx
            jmp     .loop_1


        .next_loop:
            add     rdi,    3
            mov     rsi,    rdi
            add     QWORD[rbp-104],     3

            mov     rcx,    QWORD[rbp-96]
            cmp     rcx,     QWORD[rbp-48]   ; cmp height and counted length
            jne     .loop_end_incorrect

            mov     QWORD[rbp-96],     3

            mov     rax, QWORD[rbp-104]   ; second iterator height
            cmp     rax,     QWORD[rbp-40]   ; checks columns

            jg     .loop_2
            jmp     .loop_1

        .loop_2:
            mov     rax,    rsi
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx
            cmp     rax,    QWORD[rbp-120]
            jge     .next_loop_2

            mov     QWORD[rbp-88],  6       ; stage
            jmp     .get_pixel_color

        .loop_2_continue:
            cmp     QWORD[rbp-32],  0
            jne     .next_loop_2

            add     QWORD[rbp-96],    3    ; first iterator - column
            mov     rbx,    [BYTES_PER_ROW]
            add     rsi,    rbx
            jmp     .loop_2

        .next_loop_2:
            add     rdi,    3
            mov     rsi,    rdi
            add     QWORD[rbp-104],     3

            mov     rcx,    QWORD[rbp-96]   ; cmp counted and thickness_width

            cmp     rcx,     QWORD[rbp-64]
            jne     .loop_end_incorrect

            mov     QWORD[rbp-96],     3

            mov     rax, QWORD[rbp-104]

            cmp     rax,     QWORD[rbp-56]
            jge     .loop_end_correct
            jmp     .loop_2


        .loop_end_correct:
            mov     rsi,    QWORD[rbp-80]    ; if inside correct, check outside borders
            jmp     .check_outside

        .loop_end_incorrect:
            mov     rsi,    QWORD[rbp-80]
            jmp     .go_to_next_marker

    .check_outside:
        ; [rbp-40] -> pixel after marker
        mov     QWORD [rbp-96],     3

        ; check if pixel (after width arm) is first in row
        mov     rax,    QWORD[rbp-80]
        mov     rbx,    [BYTES_PER_ROW]
        add     rax,    rbx              ; rax = address of the pixel
        sub     rax,    QWORD[rbp-8]    ; rax -= array start
        xor     rdx,    rdx              ; rdx = 0 (for div to work correctly)
        mov     rcx,    rbx
        div     rcx

        mov     rax,    rdx
        xor     rdx,    rdx
        mov     rcx,    3
        div     rcx
        mov     rbx,    0
        cmp     rbx,    rax
        je      .skip

        mov     rbx,    QWORD[rbp-64]
        mov     QWORD[rbp-104],  rbx
        add     QWORD[rbp-104],  6
        mov     rbx,    [BYTES_PER_ROW]   ; go row down
        sub     rsi,    rbx

        cmp     rsi,    QWORD[rbp-8]
        jl      .skip

        .border_1:
            mov     rax,    rsi
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx

            mov     QWORD[rbp-88],  7
            jmp     .get_pixel_color

        .border_1_continue:
            cmp     QWORD[rbp-32],  0
            je      .go_to_next_marker
            mov     rbx,    QWORD[rbp-104]
            cmp     QWORD[rbp-96],  rbx
            je      .border_1_end

            add     QWORD[rbp-96],  3    ; height of border after width
            mov     rbx,    [BYTES_PER_ROW]
            add     rsi,    rbx
            jmp     .border_1

        .skip: ; skip border_1 if pixel after mark is first in row
            mov     rsi,    QWORD[rbp-128]
            add     rsi,    QWORD[rbp-64]
            jmp     .border_1_end

        .border_1_end:
            mov     rsi,    QWORD[rbp-128]   ; goes to the point where arms cross
            add     rsi,    QWORD[rbp-40]   ; we add to it thickness of height
            mov     rbx,    [BYTES_PER_ROW] ;  we go as many rows so we are at the white pixel where arms cross
            mov     rcx,    QWORD[rbp-64]
            imul    rbx,    rcx
            mov     QWORD[rbp-104],  rbx
            add     rsi,    QWORD[rbp-104]

            mov     QWORD[rbp-96],  3
            mov     rbx,    QWORD[rbp-48]
            sub     rbx,    QWORD[rbp-64]
            mov     QWORD[rbp-104],  rbx
            add     QWORD[rbp-104],  3

            jmp     .border_2

        ; stage 8
        .border_2:
            mov     rax,    rsi
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx

            cmp     rax,    QWORD[rbp-120]
            jge     .border_2_end

            mov     QWORD[rbp-88],  8
            jmp     .get_pixel_color

        .border_2_continue:
            cmp     QWORD[rbp-32],  0
            je      .go_to_next_marker

            mov     rbx,    QWORD[rbp-104]
            cmp     QWORD[rbp-96], rbx
            je      .border_2_end
            add     QWORD[rbp-96],  3
            mov     rbx,    [BYTES_PER_ROW]
            add     rsi,    rbx
            jmp     .border_2

        .border_2_end:
            mov     QWORD[rbp-96],  3
            mov     rsi,    QWORD[rbp-128]
            sub     rsi,    3
            mov     rbx,    [BYTES_PER_ROW]
            sub     rsi,    rbx ; row down

            ; checking if the first pixel
            mov     rax,    QWORD[rbp-128]
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx              ; rax = address of the pixel
            sub     rax,    QWORD[rbp-8]    ; rax -= array start
            xor     rdx,    rdx              ; rdx = 0 (for div to work correctly)
            mov     rcx,    rbx
            div     rcx

            mov     rax,    rdx
            xor     rdx,    rdx
            mov     rcx,    3
            div     rcx
            mov     rbx,    0
            cmp     rbx,    rax
            je      .skip_2

            mov     rbx,    QWORD[rbp-48]
            mov     QWORD[rbp-104],  rbx
            add     QWORD[rbp-104],  6
            jmp     .border_3


        .skip_2: ; skip to the border before height
            mov     rsi,    QWORD[rbp-128]
            add     rsi,    QWORD[rbp-64]
            add     rsi,    QWORD[rbp-40]

            jmp     .border_3_end

        ; stage 9
        .border_3:
            mov     rax,    rsi
            mov     rbx,    [BYTES_PER_ROW]
            add     rax,    rbx

            cmp     rax,    QWORD[rbp-120]
            jge     .border_3_end

            mov     QWORD[rbp-88],  9
            jmp     .get_pixel_color

        .border_3_continue:
            cmp     QWORD[rbp-32],  0
            je      .go_to_next_marker

            mov     rbx,    QWORD[rbp-104]
            cmp     QWORD[rbp-96], rbx
            je      .border_3_end
            add     QWORD[rbp-96],  3
            mov     rbx,    [BYTES_PER_ROW]
            add     rsi,    rbx
            jmp     .border_3

        .border_3_end:
            mov     QWORD[rbp-96],  3
            mov     rbx,    QWORD[rbp-56]
            mov     QWORD[rbp-104],  rbx
            mov     rsi,    QWORD[rbp-128]
            mov     rbx,    [BYTES_PER_ROW]
            sub     rsi,    rbx     ; row  down, below the point where arms cross

            cmp     rsi,    QWORD[rbp-8]
            jl      .add_to_buffer

            jmp     .border_4

        .border_4:
            mov     rax,    rsi
            add     rax,    3

            mov     QWORD[rbp-88],  10
            jmp     .get_pixel_color

        .border_4_continue:
            cmp     QWORD[rbp-32],  0
            je      .go_to_next_marker

            mov     rbx,    QWORD[rbp-104]
            cmp     QWORD[rbp-96], rbx
            je      .border_4_end
            add     QWORD[rbp-96],  3
            add     rsi,    3
            jmp     .border_4_continue

        .border_4_end:
            mov     rsi,    QWORD[rbp-80]
            jmp     .add_to_buffer

    .add_to_buffer:
        mov     rax,    QWORD[rbp-72]
        mov     rcx,    QWORD[rbp-128]

        mov     QWORD[rax],     rcx
        add     QWORD[rbp-72],  8

        inc     QWORD[rbp-112]

        jmp     .go_to_next_marker

    .go_to_next_marker:
        mov     QWORD[rbp-88],  0
        mov     rsi,    QWORD[rbp-80]
        jmp     .next_marker

.find_marker_end:
    mov     rax,    rsi
    sub     rax,    QWORD[rbp-8]
    jmp     .end

.get_pixel_color:
    ; Getting pixel color
    mov rcx, 0
    mov cl, BYTE[rax+2]      ; R
    shl rcx, 8               ; Move 8 bits
    mov cl, BYTE[rax+1]      ; G
    shl rcx, 8               ; Move 8 bits
    mov cl, BYTE[rax]        ; B
    mov QWORD[rbp-32], rcx   ; Color

    ; Going to proper place
    mov rbx, QWORD[rbp-88]
    cmp rbx, 0
    je .next_black_continue
    cmp rbx, 1
    je .height_continue
    cmp rbx, 2
    je .thick_continue
    cmp rbx, 3
    je .width_continue
    cmp rbx, 4
    je .thickness_width_continue
    cmp rbx, 5
    je .loop_continue
    cmp rbx, 6
    je .loop_2_continue
    cmp rbx, 7
    je .border_1_continue
    cmp rbx, 8
    je .border_2_continue
    cmp rbx, 9
    je .border_3_continue
    cmp rbx, 10
    je .border_4_continue

    ; Otherwise not correct
    jmp .wrong_file_format

.wrong_file_format:
    ;mov   rax,  -1
    jmp   .return

.end:
  mov   rsi,  result_buffer
  jmp   .add_to_array

.add_to_array:
    mov     rax, [rsi]            ; address of the current pixel
    add     rsi, 8                ; next address in the result buffer

    cmp     rax, 0                ; if address = 0 -> end of buffer
    je      .return
    ; Calculate the coordinates
    mov     rbx,    [BYTES_PER_ROW]
    add   rax,  rbx
    sub   rax,  QWORD[rbp-8]    ; rax -= array start
    xor   rdx,  rdx
    mov   rcx,  rbx
    div   rcx                   ; rax /= ROW_SIZE, rdx = rax % ROW_SIZE
    mov   rcx,  [HEIGHT_VALUE]
    sub   rcx,  rax             ; Calculate Y coordinate
    mov   rdi,  [rbp-24]        ; Load address of y_pos
    mov   [rdi], rcx            ; Update y_pos


    mov     rax, rdx
    xor     rdx, rdx
    mov     rcx, 3
    div     rcx                    ; rax /= 3
    mov     rdi, [rbp-16]         ; Load address of x_pos
    mov     QWORD [rdi], rax      ; Update x_pos

    add     rsp, 24

    add     QWORD [rbp-24], 4     ; Move to the next x_pos entry
    add     QWORD [rbp-16], 4     ; Move to the next y_pos entry

    ; Return to the beginning of add_to_array to process the next pixel
    jmp     .add_to_array

.return:
    mov     rax,    QWORD[rbp-112]
    mov   rsp,  rbp
    pop   rbp
    pop   rsi
    ret
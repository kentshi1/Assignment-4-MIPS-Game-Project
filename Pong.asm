# CS240 Module 4 - Simple Pong for MARS MIPS
#
# SETUP:
# 1. Open this file in MARS, assemble it, and run it.
# 2. Open Tools > Bitmap Display. Set Unit Width = 4, Unit Height = 4,
#    Display Width = 128, Display Height = 128, Base Address = 0x10040000.
#    Click Connect to MIPS.
# 3. Open Tools > Keyboard and Display MMIO Simulator and click Connect to MIPS.
# 4. Click the MMIO keyboard input area. Press A to move left, D to move right,
#    or Q to quit. Each key press advances the ball by one step.
# 5. Keep the paddle under the ball. The score increases each time the ball
#    returns from the paddle. Missing the ball ends the game.
#
# Graphics: black field, white ball, blue paddle, green top wall.
# Uses only standard MARS Bitmap Display and Keyboard/Display MMIO tools.

.data
intro:       .asciiz "PONG\nA = left, D = right, Q = quit. Each key moves the ball one step.\nCatch the ball with the paddle.\n"
score_text:  .asciiz "Score: "
invalid_msg: .asciiz "Use A, D, or Q.\n"
miss_msg:    .asciiz "\nYou missed! Game over. Final score: "
quit_msg:    .asciiz "\nYou quit. Final score: "
newline:     .asciiz "\n"

.align 2
paddle_x: .word 13
ball_x:   .word 15
ball_y:   .word 12
ball_dx:  .word 1
ball_dy:  .word 1
score:    .word 0

.text
.globl main
main:
    jal draw_scene
    la $a0, intro
    jal print_string
    jal print_score

game_loop:
    jal read_key
    move $s0, $v0

    # Accept A/D to move, Q to quit. Invalid keys do not advance the ball.
    li $t0, 97                  # lowercase a
    beq $s0, $t0, move_left
    li $t0, 65                  # uppercase A
    beq $s0, $t0, move_left
    li $t0, 100                 # lowercase d
    beq $s0, $t0, move_right
    li $t0, 68                  # uppercase D
    beq $s0, $t0, move_right
    li $t0, 113                 # lowercase q
    beq $s0, $t0, quit_game
    li $t0, 81                  # uppercase Q
    beq $s0, $t0, quit_game
    la $a0, invalid_msg
    jal print_string
    j game_loop

move_left:
    lw $t0, paddle_x
    blez $t0, update_ball
    addiu $t0, $t0, -1
    sw $t0, paddle_x
    j update_ball

move_right:
    lw $t0, paddle_x
    li $t1, 27                  # rightmost x for a 5-unit paddle
    bge $t0, $t1, update_ball
    addiu $t0, $t0, 1
    sw $t0, paddle_x

update_ball:
    jal move_ball
    beq $v0, $zero, missed_ball
    jal draw_scene
    jal print_score
    j game_loop

missed_ball:
    la $a0, miss_msg
    jal print_string
    jal print_score_value
    la $a0, newline
    jal print_string
    j exit_game

quit_game:
    la $a0, quit_msg
    jal print_string
    jal print_score_value
    la $a0, newline
    jal print_string

exit_game:
    li $v0, 10
    syscall

# move_ball advances one step, bounces off side/top walls and paddle.
# Returns v0=1 to continue or v0=0 if the ball is missed.
move_ball:
    # Move horizontally, then bounce at the left/right edges.
    lw $t0, ball_x
    lw $t1, ball_dx
    addu $t0, $t0, $t1
    bltz $t0, bounce_left
    li $t2, 31
    bgt $t0, $t2, bounce_right
    j save_x
bounce_left:
    li $t0, 0
    li $t1, 1
    sw $t1, ball_dx
    j save_x
bounce_right:
    li $t0, 31
    li $t1, -1
    sw $t1, ball_dx
save_x:
    sw $t0, ball_x

    # Move vertically. Bounce from the top edge.
    lw $t0, ball_y
    lw $t1, ball_dy
    addu $t0, $t0, $t1
    bltz $t0, bounce_top
    j check_paddle
bounce_top:
    li $t0, 0
    li $t1, 1
    sw $t1, ball_dy
check_paddle:
    li $t2, 28
    blt $t0, $t2, save_y
    # At paddle height: the ball must be above the paddle's horizontal span.
    lw $t3, ball_x
    lw $t4, paddle_x
    blt $t3, $t4, return_missed
    addiu $t4, $t4, 5
    bge $t3, $t4, return_missed
    # Successful catch: send the ball upward and increase the score.
    li $t0, 27
    li $t1, -1
    sw $t1, ball_dy
    lw $t2, score
    addiu $t2, $t2, 1
    sw $t2, score
save_y:
    sw $t0, ball_y
    li $v0, 1
    jr $ra
return_missed:
    li $v0, 0
    jr $ra

# Redraw the playfield, paddle, ball, and top wall.
draw_scene:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal clear_screen

    # Green top wall, one unit tall.
    li $a0, 0
    li $a1, 0
    li $a2, 32
    li $a3, 1
    li $v1, 0x0000AA00
    jal draw_rect

    # Blue paddle: five units wide at y=29.
    lw $a0, paddle_x
    li $a1, 29
    li $a2, 5
    li $a3, 1
    li $v1, 0x000000FF
    jal draw_rect

    # White ball, one unit.
    lw $a0, ball_x
    lw $a1, ball_y
    li $a2, 1
    li $a3, 1
    li $v1, 0x00FFFFFF
    jal draw_rect

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

# Fill a rectangle on the bitmap.
# Inputs: a0=x, a1=y, a2=width, a3=height, v1=RGB color.
draw_rect:
    move $t0, $a0              # starting x
    move $t1, $a1              # starting y
    move $t2, $a2              # width
    move $t3, $a3              # height
    move $t7, $v1              # color
    li $t4, 0                  # row counter
rect_row:
    beq $t4, $t3, rect_done
    li $t5, 0                  # column counter
rect_col:
    beq $t5, $t2, rect_next_row
    addu $t6, $t1, $t4
    sll $t6, $t6, 5            # y * 32
    addu $t6, $t6, $t0
    addu $t6, $t6, $t5
    sll $t6, $t6, 2            # each unit uses 4 bytes
    li $t8, 0x10040000
    addu $t6, $t6, $t8
    sw $t7, 0($t6)
    addiu $t5, $t5, 1
    j rect_col
rect_next_row:
    addiu $t4, $t4, 1
    j rect_row
rect_done:
    jr $ra

# Clear all 32 x 32 bitmap units.
clear_screen:
    li $t0, 0x10040000
    li $t1, 1024
    move $t2, $zero
clear_loop:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_loop
    jr $ra

# Read one ASCII character from the MMIO receiver; return it in v0.
read_key:
read_wait:
    li $t0, 0xFFFF0000
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, read_wait
    li $t0, 0xFFFF0004
    lw $v0, 0($t0)
    andi $v0, $v0, 0x00FF
    jr $ra

# Send a null-terminated string through the MMIO transmitter.
print_string:
    move $t0, $a0
print_loop:
    lb $t1, 0($t0)
    beqz $t1, print_done
print_wait:
    li $t2, 0xFFFF0008
    lw $t3, 0($t2)
    andi $t3, $t3, 1
    beqz $t3, print_wait
    li $t2, 0xFFFF000C
    sw $t1, 0($t2)
    addiu $t0, $t0, 1
    j print_loop
print_done:
    jr $ra

# Print the score label and current score in MMIO output.
print_score:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    la $a0, score_text
    jal print_string
    jal print_score_value
    la $a0, newline
    jal print_string
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

# Print score (0-99) through MMIO.
print_score_value:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a0, score
    li $t1, 10
    divu $a0, $t1
    mflo $t2
    mfhi $t3
    beqz $t2, score_ones
    addiu $a0, $t2, 48
    jal print_char
score_ones:
    addiu $a0, $t3, 48
    jal print_char
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

# Print one ASCII character through MMIO.
print_char:
    li $t0, 0xFFFF0008
char_wait:
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, char_wait
    li $t0, 0xFFFF000C
    sw $a0, 0($t0)
    jr $ra

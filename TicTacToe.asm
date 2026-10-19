# CS240 Module 4 - Tic-Tac-Toe (two human players)
# MARS setup:
# 1. Assemble and run this file in MARS.
# 2. Open Tools > Bitmap Display. Set Unit Width = 16, Unit Height = 16,
#    Display Width = 128, Display Height = 128, Base address = 0x10010000.
#    Click Connect to MIPS.
# 3. Open Tools > Keyboard and Display MMIO Simulator and click Connect to MIPS.
# 4. Click the MMIO keyboard input area and press a number 1-9 to make a move.
#    Press the number only; Enter is not required. Red = Player 1, Blue = Player 2.
# Board positions:
#   1 2 3
#   4 5 6
#   7 8 9

.data
.align 2
bitmap_space: .space 256       # 8 x 8 bitmap units, 4 bytes per unit
board:        .space 9         # 0 = empty, 1 = player 1, 2 = player 2
prompt1:      .asciiz "Player 1 (RED), choose 1-9: "
prompt2:      .asciiz "Player 2 (BLUE), choose 1-9: "
invalid_msg:  .asciiz "Invalid key. Use 1-9.\n"
occupied_msg: .asciiz "That square is occupied. Try again.\n"
win1_msg:     .asciiz "Player 1 (RED) wins!\n"
win2_msg:     .asciiz "Player 2 (BLUE) wins!\n"
draw_msg:     .asciiz "Draw game!\n"

.text
.globl main
main:
    # Clear the board data.
    la $t0, board
    li $t1, 0
clear_board:
    beq $t1, 9, draw_empty_board
    sb $zero, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j clear_board

draw_empty_board:
    # Draw nine gray squares with one black unit between each square.
    li $s2, 0                  # row
row_loop:
    li $s3, 0                  # column
col_loop:
    li $t0, 0x10010000         # bitmap base address
    sll $t1, $s2, 6            # row * 64 bytes (skip one bitmap row)
    sll $t2, $s3, 3            # column * 8 bytes (skip one bitmap column)
    addu $t0, $t0, $t1
    addu $t0, $t0, $t2
    li $t3, 0x00555555         # gray = empty square
    sw $t3, 0($t0)
    addi $s3, $s3, 1
    blt $s3, 3, col_loop
    addi $s2, $s2, 1
    blt $s2, 3, row_loop

    li $s0, 1                  # current player (1 or 2)
    li $s1, 0                  # number of valid moves

turn_loop:
    # Show whose turn it is in the MMIO display.
    beq $s0, 1, show_prompt1
    la $a0, prompt2
    jal print_string
    j get_move
show_prompt1:
    la $a0, prompt1
    jal print_string

get_move:
    jal read_move              # returns board index 0-8 in $v0
    move $s4, $v0
    la $t0, board
    addu $t0, $t0, $s4
    lb $t1, 0($t0)
    bne $t1, $zero, square_taken

    # Save the current player's number in the board array.
    sb $s0, 0($t0)

    # Paint the chosen bitmap square red or blue.
    li $t2, 0x10010000
    li $t3, 0x00FF0000         # red for player 1
    beq $s0, 1, paint_square
    li $t3, 0x000000FF         # blue for player 2
paint_square:
    li $t4, 3
    div $s4, $t4
    mflo $t5                   # row = index / 3
    mfhi $t6                   # column = index % 3
    sll $t5, $t5, 6            # row * 64 bytes (skip one bitmap row)
    sll $t6, $t6, 3            # column * 8 bytes (skip one bitmap column)
    addu $t2, $t2, $t5
    addu $t2, $t2, $t6
    sw $t3, 0($t2)

    addi $s1, $s1, 1
    jal check_win
    bne $v0, $zero, game_won
    beq $s1, 9, game_draw

    # Switch players.
    beq $s0, 1, set_player2
    li $s0, 1
    j turn_loop
set_player2:
    li $s0, 2
    j turn_loop

square_taken:
    la $a0, occupied_msg
    jal print_string
    j turn_loop

game_won:
    beq $s0, 1, player1_won
    la $a0, win2_msg
    jal print_string
    j exit_game
player1_won:
    la $a0, win1_msg
    jal print_string
    j exit_game

game_draw:
    la $a0, draw_msg
    jal print_string

exit_game:
    li $v0, 10
    syscall

# print_string: send a zero-terminated string to the MMIO display.
# Input: $a0 = string address
print_string:
    move $t0, $a0
    li $t1, 0xFFFF0008         # transmitter control
    li $t2, 0xFFFF000C         # transmitter data
print_loop:
    lb $t3, 0($t0)
    beq $t3, $zero, print_done
wait_transmitter:
    lw $t4, 0($t1)
    andi $t4, $t4, 1
    beq $t4, $zero, wait_transmitter
    sw $t3, 0($t2)
    addi $t0, $t0, 1
    j print_loop
print_done:
    jr $ra

# read_move: wait for a keyboard character and return its board index (0-8).
# Invalid keys are reported and ignored.
read_move:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
read_again:
    li $t0, 0xFFFF0000         # receiver control
    li $t1, 0xFFFF0004         # receiver data
wait_receiver:
    lw $t2, 0($t0)
    andi $t2, $t2, 1
    beq $t2, $zero, wait_receiver
    lw $t2, 0($t1)
    andi $t2, $t2, 0x00FF
    slti $t3, $t2, 49           # ASCII '1'
    bne $t3, $zero, bad_key
    slti $t3, $t2, 58           # one past ASCII '9'
    beq $t3, $zero, bad_key
    addi $v0, $t2, -49          # convert '1'-'9' to 0-8
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
bad_key:
    la $a0, invalid_msg
    jal print_string
    j read_again

# check_win: test all eight possible three-in-a-row lines.
# Returns $v0 = 1 if a player has won, otherwise 0.
check_win:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 0
    li $a1, 1
    li $a2, 2
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 3
    li $a1, 4
    li $a2, 5
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 6
    li $a1, 7
    li $a2, 8
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 0
    li $a1, 3
    li $a2, 6
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 1
    li $a1, 4
    li $a2, 7
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 2
    li $a1, 5
    li $a2, 8
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 0
    li $a1, 4
    li $a2, 8
    jal check_line
    bne $v0, $zero, win_found
    li $a0, 2
    li $a1, 4
    li $a2, 6
    jal check_line
    bne $v0, $zero, win_found
    li $v0, 0
    j check_win_done
win_found:
    li $v0, 1
check_win_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# check_line: check the three board indexes passed in $a0-$a2.
check_line:
    la $t0, board
    addu $t1, $t0, $a0
    addu $t2, $t0, $a1
    addu $t3, $t0, $a2
    lb $t4, 0($t1)
    lb $t5, 0($t2)
    lb $t6, 0($t3)
    beq $t4, $zero, line_no_win
    bne $t4, $t5, line_no_win
    bne $t4, $t6, line_no_win
    li $v0, 1
    jr $ra
line_no_win:
    li $v0, 0
    jr $ra

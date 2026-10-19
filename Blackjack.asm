# CS240 Module 4 - Blackjack for MARS MIPS
#
# SETUP:
# 1. Open this file in MARS and assemble it.
# 2. Open Tools > Bitmap Display.
# 3. Set Unit Width = 4, Unit Height = 4, Display Width = 128,
#    Display Height = 128, and Base Address = 0x10040000 (heap).
# 4. Click Connect to MIPS in Bitmap Display.
# 5. Open Tools > Keyboard and Display MMIO Simulator and click
#    Connect to MIPS.
# 6. Run the program. Type H to hit or S to stand in the MMIO keyboard
#    input area. Use the MMIO simulator's transmit/enter control as needed.
#
# Card display: white cards with colored pip blocks. Values are also
# printed in the MMIO text display. This uses only standard MARS features.

.data
intro:      .asciiz "BLACKJACK\nH = hit, S = stand. Try to get close to 21 without going over.\n"
dealerMsg:  .asciiz "\nDealer hand: "
playerMsg:  .asciiz "\nYour hand: "
scoreMsg:   .asciiz "  Total: "
newline:    .asciiz "\n"
hitPrompt:  .asciiz "\nHit or stand? (H/S): "
invalidMsg: .asciiz "Please type H or S.\n"
bustMsg:    .asciiz "\nYou busted. Dealer wins.\n"
winMsg:     .asciiz "\nYou win!\n"
loseMsg:    .asciiz "\nDealer wins.\n"
tieMsg:     .asciiz "\nPush (tie).\n"
endMsg:     .asciiz "Game over. Reset the program to play again.\n"

.align 2
playerCards: .space 24
dealerCards: .space 24
playerCount: .word 0
dealerCount: .word 0
playerTotal: .word 0
dealerTotal: .word 0
seed:        .word 37

.text
.globl main
main:
    # Initialize and paint the green table.
    jal clear_screen
    la $a0, intro
    jal print_string

    # Deal two cards to each side.
    li $t0, 0
    sw $t0, playerCount
    sw $t0, dealerCount
    jal random_card
    move $a0, $v0
    jal add_player_card
    jal random_card
    move $a0, $v0
    jal add_dealer_card
    jal random_card
    move $a0, $v0
    jal add_player_card
    jal random_card
    move $a0, $v0
    jal add_dealer_card
    jal update_totals
    jal draw_game
    jal show_hands

player_turn:
    lw $t0, playerTotal
    bgt $t0, 21, player_bust
    la $a0, hitPrompt
    jal print_string
    jal read_key
    move $t0, $v0
    li $t1, 104          # 'h'
    beq $t0, $t1, player_hit
    li $t1, 72           # 'H'
    beq $t0, $t1, player_hit
    li $t1, 115          # 's'
    beq $t0, $t1, dealer_turn
    li $t1, 83           # 'S'
    beq $t0, $t1, dealer_turn
    la $a0, invalidMsg
    jal print_string
    j player_turn

player_hit:
    lw $t0, playerCount
    bge $t0, 5, dealer_turn
    jal random_card
    move $a0, $v0
    jal add_player_card
    jal update_totals
    jal draw_game
    jal show_hands
    j player_turn

player_bust:
    la $a0, bustMsg
    jal print_string
    j game_over

dealer_turn:
    # Dealer draws while below 17.
dealer_loop:
    lw $t0, dealerTotal
    bge $t0, 17, compare_hands
    lw $t1, dealerCount
    bge $t1, 5, compare_hands
    jal random_card
    move $a0, $v0
    jal add_dealer_card
    jal update_totals
    jal draw_game
    jal show_hands
    j dealer_loop

compare_hands:
    lw $t0, dealerTotal
    bgt $t0, 21, player_wins
    lw $t1, playerTotal
    bgt $t1, $t0, player_wins
    beq $t1, $t0, tie_game
    la $a0, loseMsg
    jal print_string
    j game_over

player_wins:
    la $a0, winMsg
    jal print_string
    j game_over

tie_game:
    la $a0, tieMsg
    jal print_string

game_over:
    la $a0, endMsg
    jal print_string
    li $v0, 10
    syscall

# Print a null-terminated string through MMIO transmitter.
print_string:
    move $t0, $a0
print_loop:
    lb $t1, 0($t0)
    beqz $t1, print_done
print_wait:
    li $t2, 0xffff0008
    lw $t3, 0($t2)
    andi $t3, $t3, 1
    beqz $t3, print_wait
    li $t2, 0xffff000c
    sw $t1, 0($t2)
    addiu $t0, $t0, 1
    j print_loop
print_done:
    jr $ra

# Read one character from MMIO receiver; return it in $v0.
read_key:
read_wait:
    li $t0, 0xffff0000
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, read_wait
    li $t0, 0xffff0004
    lw $v0, 0($t0)
    jr $ra

# Simple deterministic pseudo-random card value from 2 through 11 (Ace).
random_card:
    lw $t0, seed
    li $t1, 1103515245
    multu $t0, $t1
    mflo $t0
    addiu $t0, $t0, 12345
    sw $t0, seed
    li $t1, 10
    divu $t0, $t1
    mfhi $v0
    addiu $v0, $v0, 2
    jr $ra

# Add card value in $a0 to player's array.
add_player_card:
    lw $t0, playerCount
    la $t1, playerCards
    sll $t2, $t0, 2
    addu $t1, $t1, $t2
    sw $a0, 0($t1)
    addiu $t0, $t0, 1
    sw $t0, playerCount
    jr $ra

# Add card value in $a0 to dealer's array.
add_dealer_card:
    lw $t0, dealerCount
    la $t1, dealerCards
    sll $t2, $t0, 2
    addu $t1, $t1, $t2
    sw $a0, 0($t1)
    addiu $t0, $t0, 1
    sw $t0, dealerCount
    jr $ra

# Recalculate totals; Ace (11) counts as 1 if total would exceed 21.
update_totals:
    li $t0, 0
    li $t1, 0
    lw $t2, playerCount
    la $t3, playerCards
player_sum_loop:
    beq $t1, $t2, player_sum_done
    sll $t4, $t1, 2
    addu $t5, $t3, $t4
    lw $t6, 0($t5)
    # Values 10 and 11 represent 10 and Ace; 2-9 retain face value.
    li $t7, 11
    beq $t6, $t7, player_ace
    add $t0, $t0, $t6
    j player_sum_next
player_ace:
    addiu $t0, $t0, 11
player_sum_next:
    addiu $t1, $t1, 1
    j player_sum_loop
player_sum_done:
    # Convert aces from 11 to 1 until the hand is <= 21 or no ace remains.
    sw $t0, playerTotal
    lw $t1, playerCount
    la $t2, playerCards
    move $t3, $zero
player_ace_count_loop:
    beq $t3, $t1, player_ace_count_done
    sll $t4, $t3, 2
    addu $t5, $t2, $t4
    lw $t6, 0($t5)
    li $t7, 11
    bne $t6, $t7, player_ace_count_next
    lw $t8, playerTotal
    ble $t8, 21, player_ace_count_next
    addiu $t8, $t8, -10
    sw $t8, playerTotal
player_ace_count_next:
    addiu $t3, $t3, 1
    j player_ace_count_loop
player_ace_count_done:
    # Recalculate dealer total the same way.
    li $t0, 0
    li $t1, 0
    lw $t2, dealerCount
    la $t3, dealerCards
dealer_sum_loop:
    beq $t1, $t2, dealer_sum_done
    sll $t4, $t1, 2
    addu $t5, $t3, $t4
    lw $t6, 0($t5)
    li $t7, 11
    beq $t6, $t7, dealer_ace
    add $t0, $t0, $t6
    j dealer_sum_next
dealer_ace:
    addiu $t0, $t0, 11
dealer_sum_next:
    addiu $t1, $t1, 1
    j dealer_sum_loop
dealer_sum_done:
    sw $t0, dealerTotal
    lw $t1, dealerCount
    la $t2, dealerCards
    move $t3, $zero
dealer_ace_count_loop:
    beq $t3, $t1, totals_done
    sll $t4, $t3, 2
    addu $t5, $t2, $t4
    lw $t6, 0($t5)
    li $t7, 11
    bne $t6, $t7, dealer_ace_count_next
    lw $t8, dealerTotal
    ble $t8, 21, dealer_ace_count_next
    addiu $t8, $t8, -10
    sw $t8, dealerTotal
dealer_ace_count_next:
    addiu $t3, $t3, 1
    j dealer_ace_count_loop
totals_done:
    jr $ra

# Clear the 32x32 bitmap to green, then draw simple card-table lines.
clear_screen:
    li $t0, 0x10040000
    li $t1, 1024
    li $t2, 0x006633
clear_loop:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_loop
    jr $ra

# Draw all cards using small white rectangles and colored pips.
draw_game:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    jal clear_screen
    li $s0, 0
    lw $s1, dealerCount
    la $s2, dealerCards
draw_dealer_loop:
    beq $s0, $s1, draw_player_start
    sll $t0, $s0, 2
    addu $t1, $s2, $t0
    lw $a2, 0($t1)
    sll $a0, $s0, 1
    addu $a0, $a0, $s0
    sll $a0, $a0, 1
    addiu $a0, $a0, 2
    li $a1, 2
    jal draw_card
    addiu $s0, $s0, 1
    j draw_dealer_loop
draw_player_start:
    li $s0, 0
    lw $s1, playerCount
    la $s2, playerCards
draw_player_loop:
    beq $s0, $s1, draw_game_done
    sll $t0, $s0, 2
    addu $t1, $s2, $t0
    lw $a2, 0($t1)
    sll $a0, $s0, 1
    addu $a0, $a0, $s0
    sll $a0, $a0, 1
    addiu $a0, $a0, 2
    li $a1, 17
    jal draw_card
    addiu $s0, $s0, 1
    j draw_player_loop
draw_game_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# Draw a card at unit coordinate ($a0,$a1); value is in $a2.
# Each card is 5x7 units; pips encode the value visually.
draw_card:
    addiu $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s0, 20($sp)
    sw $s1, 16($sp)
    sw $s2, 12($sp)
    sw $s3, 8($sp)
    sw $s4, 4($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    # Black outline, then white card face.
    move $a0, $s0
    move $a1, $s1
    li $a2, 5
    li $a3, 7
    li $t0, 0x000000
    jal draw_rect
    addiu $a0, $s0, 1
    addiu $a1, $s1, 1
    li $a2, 3
    li $a3, 5
    li $t0, 0xFFFFFF
    jal draw_rect
    # Red pips for even values, black pips for odd values/Ace.
    andi $t1, $s2, 1
    bnez $t1, card_black_pips
    li $s3, 0xFF2222
    j card_pips_start
card_black_pips:
    li $s3, 0x111111
card_pips_start:
    move $s4, $zero
card_pips_loop:
    # Show 1-10 pips (Ace is drawn as one pip).
    move $t3, $s2
    li $t4, 11
    bne $t3, $t4, card_value_ready
    li $t3, 1
card_value_ready:
    bge $s4, $t3, card_draw_done
    # Pips fill three columns across the card interior.
    li $t4, 3
    divu $s4, $t4
    mfhi $t5
    mflo $t6
    addiu $a0, $s0, 1
    addu $a0, $a0, $t5
    addiu $a1, $s1, 1
    addu $a1, $a1, $t6
    li $a2, 1
    li $a3, 1
    move $t0, $s3
    jal draw_rect
    addiu $s4, $s4, 1
    j card_pips_loop
card_draw_done:
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $s0, 20($sp)
    lw $ra, 24($sp)
    addiu $sp, $sp, 28
    jr $ra

# Filled rectangle: x=$a0, y=$a1, width=$a2, height=$a3, color=$t0.
# Bitmap base is 0x10040000; 32 units per row, one word per unit.
draw_rect:
    addiu $sp, $sp, -28
    sw $s0, 24($sp)
    sw $s1, 20($sp)
    sw $s2, 16($sp)
    sw $s3, 12($sp)
    sw $s4, 8($sp)
    sw $s5, 4($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    move $s4, $t0
    move $s5, $zero
rect_y_loop:
    beq $s5, $s3, rect_done
    move $t1, $zero
rect_x_loop:
    beq $t1, $s2, rect_next_row
    addu $t2, $s1, $s5
    sll $t2, $t2, 5
    addu $t2, $t2, $s0
    addu $t2, $t2, $t1
    sll $t2, $t2, 2
    li $t3, 0x10040000
    addu $t3, $t3, $t2
    sw $s4, 0($t3)
    addiu $t1, $t1, 1
    j rect_x_loop
rect_next_row:
    addiu $s5, $s5, 1
    j rect_y_loop
rect_done:
    lw $s5, 4($sp)
    lw $s4, 8($sp)
    lw $s3, 12($sp)
    lw $s2, 16($sp)
    lw $s1, 20($sp)
    lw $s0, 24($sp)
    addiu $sp, $sp, 28
    jr $ra

# Print both hands and their totals.
show_hands:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    la $a0, dealerMsg
    jal print_string
    lw $s0, dealerCount
    la $s1, dealerCards
    move $s2, $zero
show_dealer_loop:
    beq $s2, $s0, show_dealer_total
    sll $t3, $s2, 2
    addu $t4, $s1, $t3
    lw $a0, 0($t4)
    jal print_number
    li $a0, 32
    jal print_char
    addiu $s2, $s2, 1
    j show_dealer_loop
show_dealer_total:
    la $a0, scoreMsg
    jal print_string
    lw $a0, dealerTotal
    jal print_number
    la $a0, playerMsg
    jal print_string
    lw $s0, playerCount
    la $s1, playerCards
    move $s2, $zero
show_player_loop:
    beq $s2, $s0, show_player_total
    sll $t3, $s2, 2
    addu $t4, $s1, $t3
    lw $a0, 0($t4)
    jal print_number
    li $a0, 32
    jal print_char
    addiu $s2, $s2, 1
    j show_player_loop
show_player_total:
    la $a0, scoreMsg
    jal print_string
    lw $a0, playerTotal
    jal print_number
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# Print unsigned integer in $a0 using repeated division.
print_number:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    move $s0, $a0
    li $t0, 10
    divu $s0, $t0
    mflo $s1
    mfhi $s2
    beqz $s1, number_ones
    addiu $a0, $s1, 48
    jal print_char
number_ones:
    addiu $a0, $s2, 48
    jal print_char
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# Print ASCII character in $a0 through MMIO.
print_char:
char_wait:
    li $t0, 0xffff0008
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, char_wait
    li $t0, 0xffff000c
    sw $a0, 0($t0)
    jr $ra

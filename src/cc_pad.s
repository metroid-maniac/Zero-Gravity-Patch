# hook: the game's per-frame GameCube pad poll, right after PADRead has filled the
# PADStatus[4] buffer (`lwz r3,0x80(r20)`, then PADClamp).  For every port that has
# no real pad (err != 0) but whose Wii Remote channel has a Classic Controller or
# Nunchuk attached, fill that port's PADStatus from the game's own KPAD status
# (KBASE + chan*0x840, newest sample first, 0x84 bytes per sample):
#   +0x00 Wii Remote + Nunchuk hold bits
#   +0x5C dev_type (1 = Nunchuk, 2 = Classic)   +0x5D wpad_err
#   +0x60 Nunchuk stick x,y (floats) / Classic hold bits
#   +0x6C Classic lstick x,y  +0x74 rstick x,y  (floats)
#   +0x7C ltrigger  +0x80 rtrigger (floats 0..1)
# so the rest of the game sees an ordinary GameCube controller.  Sticks are scaled
# by 100 (a GameCube pad's full-scale value in the game's own input), triggers by 200.
    stwu    1, -0x40(1)
.if DBG
    lis     4, 0x8000
    ori     4, 4, 0x2F00
    lwz     5, 0(4)
    addi    5, 5, 1
    stw     5, 0(4)                     # call counter
    lwz     5, 0x80(20)
    stw     5, 4(4)                     # PADStatus ptr
    lbz     5, 10(5)
    stw     5, 8(4)                     # err of port 0
    lis     8, KBASE@ha
    addi    8, 8, KBASE@l
    lbz     5, 0x5c(8)
    stw     5, 12(4)                    # dev type seen
    lwz     5, 0x60(8)
    stw     5, 16(4)
.endif
    lis     0, 0x42c8                   # 100.0f
    stw     0, 0x08(1)
    lis     0, 0x4348                   # 200.0f
    stw     0, 0x0c(1)
    lfs     10, 0x08(1)                 # f10 = stick scale
    lfs     11, 0x0c(1)                 # f11 = trigger scale
    lwz     3, 0x80(20)                 # PADStatus[4]
    lis     8, KBASE@ha
    addi    8, 8, KBASE@l
    li      9, 0
1:  lbz     0, 10(3)
    extsb.  0, 0
    beq     9f                          # a real pad answers: leave it alone
    lbz     0, 0x5d(8)
    extsb.  0, 0
    bne     9f
    lbz     0, 0x5c(8)
    cmpwi   0, 2
    beq     2f                          # Classic Controller
    cmpwi   0, 1
    bne     9f                          # neither Classic Controller nor Nunchuk
    lwz     4, 0x00(8)                  # Wii Remote + Nunchuk buttons
    rlwinm  5, 4, 29, 23, 23            # A (0x0800)    -> GC A (0x0100) Jump/Trick
    rlwinm  6, 4, 31, 22, 22            # B (0x0400)    -> GC B (0x0200) Gravity control/drift
    or      5, 5, 6
    rlwinm  6, 4, 8, 21, 21             # Down (0x0004) -> GC X (0x0400) Brake
    or      5, 5, 6
    rlwinm  6, 4, 29, 20, 20            # C (0x4000)    -> GC Y (0x0800) Activate gear parts
    or      5, 5, 6
    rlwinm  6, 4, 8, 19, 19             # + (0x0010)    -> GC Start (0x1000) Pause
    or      5, 5, 6
    rlwinm  6, 4, 25, 25, 25            # Z (0x2000)    -> GC L (0x0040) Gravity dive
    or      5, 5, 6
    sth     5, 0(3)
    lfs     0, 0x60(8)                  # Nunchuk stick x
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 2(3)
    lfs     0, 0x64(8)                  # Nunchuk stick y
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 3(3)
    li      0, 0
    sth     0, 4(3)                     # C-stick x, y
    mulli   6, 6, 3                     # 192 if Z held, else 0
    stb     6, 6(3)                     # analog L trigger
    stb     0, 7(3)                     # analog R trigger
    sth     0, 8(3)                     # analog A, B
    stb     0, 10(3)                    # err = PAD_ERR_NONE
    # suppress this channel's Wii Remote slot (r23 + 0x1C0 + chan*0x70) so
    # Wii Remote buttons/motion do not double-fire alongside the GC slot;
    # keep only the HOME button bit (0x00400000).
    mulli   4, 9, 0x70
    addi    4, 4, 0x1c0
    add     4, 4, 23
    lwz     5, 0x00(4)
    andis.  5, 5, 0x0040
    stw     5, 0x00(4)
    lwz     5, 0x04(4)
    andis.  5, 5, 0x0040
    stw     5, 0x04(4)
    lwz     5, 0x08(4)
    andis.  5, 5, 0x0040
    stw     5, 0x08(4)
    lwz     5, 0x0c(4)
    andis.  5, 5, 0x0040
    stw     5, 0x0c(4)
    addi    4, 4, 0x24
    li      5, 15
3:  stw     0, 0(4)
    addi    4, 4, 4
    addic.  5, 5, -1
    bne     3b
    b       9f
2:  lwz     4, 0x60(8)                  # Classic buttons
    rlwinm  5, 4, 4, 23, 23             # A      -> A
    rlwinm  6, 4, 3, 22, 22             # B      -> B
    or      5, 5, 6
    rlwinm  6, 4, 7, 21, 21             # X      -> X
    or      5, 5, 6
    rlwinm  6, 4, 6, 20, 20             # Y      -> Y
    or      5, 5, 6
    rlwinm  6, 4, 2, 19, 19             # +      -> Start
    or      5, 5, 6
    rlwinm  6, 4, 25, 25, 25            # L click-> L
    or      5, 5, 6
    rlwinm  6, 4, 28, 26, 26            # R click-> R
    or      5, 5, 6
    rlwinm  6, 4, 29, 27, 27            # ZL     -> Z
    or      5, 5, 6
    rlwinm  6, 4, 2, 27, 27             # ZR     -> Z
    or      5, 5, 6
    rlwinm  6, 4, 31, 25, 25            # ZL     -> L (Z does nothing in the game)
    or      5, 5, 6
    rlwinm  6, 4, 3, 26, 26             # ZR     -> R
    or      5, 5, 6
    rlwinm  6, 4, 3, 28, 28             # Up
    or      5, 5, 6
    rlwinm  6, 4, 31, 31, 31            # Left
    or      5, 5, 6
    rlwinm  6, 4, 20, 29, 29            # Down
    or      5, 5, 6
    rlwinm  6, 4, 18, 30, 30            # Right
    or      5, 5, 6
    sth     5, 0(3)
    lfs     0, 0x6c(8)                  # left stick x
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 2(3)
    lfs     0, 0x70(8)                  # left stick y
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 3(3)
    lfs     0, 0x74(8)                  # right stick x
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 4(3)
    lfs     0, 0x78(8)                  # right stick y
    fmuls   0, 0, 10
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 5(3)
    lfs     0, 0x7c(8)                  # left trigger
    fmuls   0, 0, 11
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 6(3)
    lfs     0, 0x80(8)                  # right trigger
    fmuls   0, 0, 11
    fctiwz  0, 0
    stfd    0, 0x10(1)
    lwz     4, 0x14(1)
    stb     4, 7(3)
    li      0, 0
    sth     0, 8(3)                     # analog A, B
    stb     0, 10(3)                    # err = PAD_ERR_NONE
9:  addi    3, 3, 12
    addi    8, 8, 0x840
    addi    9, 9, 1
    cmpwi   9, 4
    blt     1b
    addi    1, 1, 0x40
    lwz     3, 0x80(20)                 # displaced instruction

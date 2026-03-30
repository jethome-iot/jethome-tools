/* SPDX-License-Identifier: (GPL-2.0+ OR MIT) */
/*
 * Copyright (c) 2019 Amlogic, Inc. All rights reserved.
 */

#ifndef __S7D_MBOX_H__
#define __S7D_MBOX_H__

#include "amlogic,mbox.h"

// MBOX DRIVER ID
#define S7D_AO2REE        0
#define S7D_REE2AO0       (S7D_AO2REE + 1)
#define S7D_REE2AO1       (S7D_AO2REE + 2)
#define S7D_REE2AO2       (S7D_AO2REE + 3)
#define S7D_REE2AO3       (S7D_AO2REE + 4)
#define S7D_REE2AO4       (S7D_AO2REE + 5)
#define S7D_REE2AO5       (S7D_AO2REE + 6)
#define S7D_REE2AO6       (S7D_AO2REE + 7)
#define S7D_REE2AO7       (S7D_AO2REE + 8)
#define S7D_REE2AO8       (S7D_AO2REE + 9)

// DEVICE TREE ID
#define S7D_REE2AO_DEV    S7D_REE2AO0
#define S7D_REE2AO_VRTC   S7D_REE2AO1
#define S7D_REE2AO_KEYPAD S7D_REE2AO2
#define S7D_REE2AO_AOCEC  S7D_REE2AO3
#define S7D_REE2AO_ETH    S7D_REE2AO4
#define S7D_REE2AO_LED    S7D_REE2AO5
#define S7D_REE2AO_IR     S7D_REE2AO6

// MBOX CHANNEL ID
#define S7D_MBOX_AO2REE    2
#define S7D_MBOX_REE2AO    3
#define S7D_MBOX_NUMS      2

// AOCPU STATUS MBOX CHANNEL ID
#define S7D_MBOX_AO2TEE    4

#endif /* __S7D_MBOX_H__ */

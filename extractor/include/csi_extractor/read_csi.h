/*
 * =====================================================================================
 *       Filename:  read_csi.h
 *
 *    Description:  CSI extraction helpers
 *        Version:  1.0
 *
 *         Author:  Fabian Portner
 *         Email :  <fportner@tudelft.nl>
 *   Organization:  WISE @ TU Delft
 *
 *   Copyright (c)  WISE @ TU Delft
 *
 * Based off of:
 *    https://github.com/xieyaxiongfly/Atheros-CSI-Tool-UserSpace-APP
 *    Yaxiong Xie, WANDS group @ Nanyang Technological University
 * =====================================================================================
 */
#include <sys/types.h>

// TODO: Improve this somehow. Ideally, we would have the kernel module as CMake
// project with the CSI part being mostly extracted into a separate library
// which we could then link this application against, I guess?
#include "../../driver/module_src/ath/ath9k/ath9k_csi.h"

typedef struct {
    int real;
    int imag;
} Complex;

/*!
 * Open kernel CSI character device for streaming
 */
int open_csi_device();

/*!
 * Open kernel CSI character device
 * @param fd File descriptor of CSI character device
 */
void close_csi_device(int fd);

/*!
 * Read CSI packet into userspace buffer.
 * @param buf_addr Out param for buffer to write packet into
 * @param bufsize  (Maximum) size of buffer
 * @param fd       Character device file descriptor
 */
int read_csi_packet(u_int8_t* buf_addr, int bufsize, int fd);

/*!
 * Unpack a single CSI packet reported from the kernel.
 * @param buf_addr   The address at which the packet starts
 * @param user_info  Out param to write csi user info (CSI packet header) to
 * @param csi_matrix Out param to write CSI array to
 */
void unpack_csi_packet(u_int8_t const* buf_addr,
                       csi_user_info*  user_info,
                       Complex (*csi_matrix)[3][114]);


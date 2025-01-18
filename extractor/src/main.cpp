/*
 * =====================================================================================
 *       Filename:  main.c
 *
 *    Description:  CSI extractor to read CSI from modified ath9k kernel module
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

#include <errno.h>   // For error number on file open error
#include <signal.h>  // for signal handling
#include <stdio.h>   // for printf
#include <stdlib.h>  // For malloc and free

#include "csi_extractor/read_csi.h"


#define BUFSIZE  4096

static volatile int quit = 0;

/*!
 * Signal handler to catch when to quit capturing
 */
void sig_handler(int signo)
{
    if ((signo == SIGINT) || (signo == SIGHUP)) {
        quit = 1;
    }
}

int main(int argc, char* argv[])
{
    FILE* fp;
    int   fd, total_msg_cnt, cnt, log_flag;

    // Buffers and temp CSI structs
    unsigned char csi_buffer[BUFSIZE];
    Complex       csi_matrix[3][3][114];
    csi_user_info user_info;

    log_flag      = 1;
    total_msg_cnt = 0;

    if (argc == 1) {
        log_flag = 0;
        printf(
            "=====================================================\n"
            "==========  Usage: recv_csi <output_file>  ==========\n"
            "=====================================================\n");
    } else if (argc == 2) {
        fp = fopen(argv[1], "w");
        if (!fp) {
            printf("Failed to open <output_file>, are you root?\n");
            fclose(fp);
            return 1;
        }
    } else {
        printf("Too many input arguments, expected only a file or nothing!!\n");
        return 1;
    }

    // Open ath9k kernel module character device
    fd = open_csi_device();
    if (fd < 0) {
        perror(
            "Failed to open CSI kernel device;"
            "Did you install the modified kernel device driver? "
            "Did you close other applications accessing it?"
        );
        close_csi_device(fd);
        return errno;
    }

    printf(
        "=====================================================\n"
        "===== Receiving CSI data! Press Ctrl+C to quit! =====\n"
        "=====================================================\n");

    while (1) {
        if (quit) {
            break;
        }

        // Await CSI packets from kernel character device
        cnt = read_csi_packet(csi_buffer, BUFSIZE, fd);
        if (cnt == 0) {
            continue;
        }

        // New packet received, unpack into usable structures!
        total_msg_cnt += 1;
        unpack_csi_packet(csi_buffer, &user_info, csi_matrix);

        #ifdef DEBUG
        printf(
            "Received message. (t=%lu, num received=%d) \n"
            "  -- Rate          : 0x%02x \n"
            "  -- Sequence num  : %d\n"
            "  -- CSI Frame len : %d \n",
            user_info.pkt_status.tstamp,
            total_msg_cnt,
            user_info.pkt_status.rate,
            user_info.sequence_num,
            user_info.csi_frame_len);
        #endif

        // Log unpacked user info (CSI packet header) and CSI values for offline
        // processing.
        if (log_flag) {
            fwrite(&user_info, sizeof(struct csi_user_info), 1, fp);
            fwrite(csi_matrix, sizeof(csi_matrix), 1, fp);
        }
    }

    fclose(fp);
    close_csi_device(fd);
    return 0;
}

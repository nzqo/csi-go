/*
 * =====================================================================================
 *       Filename:  read_csi.c
 *
 *    Description:  CSI extraction helpers implementation
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
#include "csi_extractor/read_csi.h"

#include <fcntl.h>   // for open
#include <unistd.h>  // for close
#include <chrono>    // overwriting kernel timestamp due to non-monotonicity

static int bit_convert(int data, int maxbit)
{
    if (data & (1 << (maxbit - 1))) {
        /* negative */
        data -= (1 << maxbit);
    }
    return data;
}

/*
 * The complex values are stored with 10 bit resolution for each
 * complex- and real value. This means we need to read 10 bits at
 * a time from the buffer. We keep a data window that contains at
 * least 10 bit (the lower 10) at all times.
 * We do so by feeding further bytes from the buffer whenever the
 * count of unprocessed bits in the window drops below 10.
 */
static int const window_size = 10;
struct ReadState {
    u_int8_t const* buffer;       // Pointer to start of buffer
    u_int8_t        bits_left;    // Number of unprocessed bits in window
    u_int32_t       buffer_idx;   // Current buffer position
    u_int32_t       data_window;  // Temporary data window of at least window_size bit
};

typedef struct ReadState ReadState;

/*!
 * Fetch next two bytes from buffer.
 *
 * @note: The window can hold 32 bits. In the worst case, 9 bits are still
 * present, which isn't enough to process a 10-bit int. Fetching two bytes
 * will result in a window of 25 bits. Hence, with a 32-bit window, we can
 * not fetch more than two anyway.
 */
static void fetch_next_bytes(ReadState* state)
{
    u_int32_t tmp_data, idx;

    // Get next 16 bits from the buffer (feed front)
    idx      = state->buffer_idx;
    tmp_data = state->buffer[idx] | state->buffer[idx + 1] << 8;

    // Feed those 16 bits to the front of the data window
    state->data_window += tmp_data << state->bits_left;

    // Advance: Now window contains 16 more bits, while 2 more bytes of
    // buffer have been processed.
    state->bits_left += 16;
    state->buffer_idx += 2;
}

/*!
 * Advance window after having read its contents.
 */
static void advance_window(ReadState* state)
{
    state->data_window >>= window_size;
    state->bits_left -= window_size;
}

/*!
 * Read next ten bits from the buffer.
 */
static int read_ten_bits(ReadState* state)
{
    int value;

    // Bitmask to extract lowest 10 bit
    u_int32_t bitmask = (1 << window_size) - 1;

    // Ensure availability of 10 bit in Reader's data window
    if (state->bits_left < window_size) {
        fetch_next_bytes(state);
    }

    // Extract data and convert to 10-bit precision integer
    value = state->data_window & bitmask;
    value = bit_convert(value, 10);

    // Advance and return value
    advance_window(state);
    return value;
}

static void fill_csi_matrix(u_int8_t const* csi_addr,
                            int             num_rx_antennas,
                            int             num_tx_antennas,
                            int             num_tones,
                            Complex (*csi_matrix)[3][114])
{
    u_int8_t subc, nr_idx, nc_idx;

    ReadState reader_state = {
        .buffer      = csi_addr,
        .bits_left   = 0,
        .buffer_idx  = 0,
        .data_window = 0,
    };

    // loop through all subcarriers, tx antennas and rx antennas.
    for (subc = 0; subc < num_tones; subc++) {
        for (nc_idx = 0; nc_idx < num_tx_antennas; nc_idx++) {
            for (nr_idx = 0; nr_idx < num_rx_antennas; nr_idx++) {
                csi_matrix[nr_idx][nc_idx][subc].imag = read_ten_bits(&reader_state);
                csi_matrix[nr_idx][nc_idx][subc].real = read_ten_bits(&reader_state);
            }
        }
    }
}

int open_csi_device()
{
    int fd;
    fd = open("/dev/CSI_dev", O_RDWR);
    return fd;
}

void close_csi_device(int fd)
{
    close(fd);
}

int read_csi_packet(u_int8_t* buf_addr, int bufsize, int fd)
{
    // Listen to the CSI kernel character device. Read finished when:
    //  1. A CSI value is reported from the kernel module
    //  2. A timeout occurs
    int cnt = read(fd, buf_addr, bufsize);
    return cnt;
}

void unpack_csi_packet(u_int8_t const* buf_addr,
                       csi_user_info*  user_info,
                       Complex (*csi_matrix)[3][114])
{
    int             i, num_rx_antennas, num_tx_antennas, num_tones;
    u_int8_t const *csi_addr;

    struct csi_pkt_status* csi_status = &(user_info->pkt_status);


    // ---------------------------------------------------------------
    // Extract data from buffer
    // The CSI packets from the kernel are structured as follows:
    //   CSI User Info (Header)  |  CSI values

    // First unpack header. Since we are on the same machine as the kernel
    // module, we can simply reinterpret the memcopied binary values here,
    // no need to care for anything.
    *user_info = *(struct csi_user_info*) (buf_addr);

    // Overwriting the timestamp taken in the kernel since the clock is non-monotonic
    // so heavily that it messes up the data all the time. We take just a microsecond
    // timestamp here, at the cost of losing some accuracy and delay..
    auto now = std::chrono::system_clock::now();
    auto micros = std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch()).count();    
    csi_status->sys_tstamp_ns = micros * 1000;

    // Next, fill the CSI values
    csi_addr = buf_addr + sizeof(struct csi_user_info);
    fill_csi_matrix(csi_addr,
                    csi_status->num_rx_antennas,
                    csi_status->num_tx_antennas,
                    csi_status->num_tones,
                    csi_matrix);
}

void process_csi(u_int8_t const*      data_buf,
                 csi_user_info const* csi_user_info,
                 Complex const (*csi_buf)[3][114])
{
    /* here is the function for csi processing
     * you can install your own function */
    return;
}

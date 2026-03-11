parameter int DIN_WIDTH_P = 8;
parameter int N_P         = 4;

typedef logic signed [DIN_WIDTH_P-1:0]  din_t;
typedef logic signed [2*DIN_WIDTH_P-1:0] acc_t;
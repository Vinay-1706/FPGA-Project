# top_fp_div.xdc
# Clock on pin example - replace PACKAGE_PIN with your board's pin
# Example for a generic board; change as needed.
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.0 -name clk_100MHz [get_ports clk]

# Reset pin example (active low)
set_property PACKAGE_PIN V4 [get_ports rstn]
set_property IOSTANDARD LVCMOS33 [get_ports rstn]

# If you have result_out and result_valid_out pins for hardware
#set_property PACKAGE_PIN ... [get_ports result_out]
#set_property PACKAGE_PIN ... [get_ports result_valid_out]

package ParseEDID;
# CVT_ratios:
my @known_ratios = qw(5/4 4/3 3/2 16/10 15/9 16/9);

# Set values
my @edid_info = (
	['a8',  '_header'],
	['a2',  'manufacturer_name'],
	['v',   'product_code'],
	['V',   'serial_number'],
	['C',   'week'],
	['C',   'year'],
	['C',   'edid_version'],
	['C',   'edid_revision'],
	['a',   'video_input_definition'],
	['C',   'max_size_horizontal'], # in cm, 0 on projectors
	['C',   'max_size_vertical'], # in cm, 0 on projectors
	['C',   'gamma'],
	['a',   'feature_support'],
	['a10', 'color_characteristics'],
	['a3' , 'established_timings'],
	['a16', 'standard_timings'],
	['a72', 'monitor_details'],
	['C',   'extension_flag'],
	['C',   'checksum'],
);
my %subfields = (
	manufacturer_name => [
		[1, ''],
		[5, '1'],
		[5, '2'],
		[5, '3'],
	],
	video_input_definition => [
		[1, 'digital'],
		[1, 'separate_sync'],
		[1, 'composite_sync'],
		[1, 'sync_on_green'],
		[2, ''],
		[2, 'voltage_level'],
	],
	feature_support => [
		[1, 'DPMS_standby'],
		[1, 'DPMS_suspend'],
		[1, 'DPMS_active_off'],		
		[1, 'rgb'],
		[1, ''],
		[1, 'sRGB_compliance'],
		[1, 'has_preferred_timing'],
		[1, 'GTF_compliance'],
	],
	# these are VESA timings, basically: VESA-EEDID-A2.pdf
	established_timings => [
		# byte 1, 23h
		[1, '720x400_70'],
		[1, '720x400_88'],
		[1, '640x480_60'],
		[1, '640x480_67'],
		[1, '640x480_72'],
		[1, '640x480_75'],
		[1, '800x600_56'],
		[1, '800x600_60'],
		# byte 2, 24h
		[1, '800x600_72'],
		[1, '800x600_75'],
		[1, '832x624_75'],
		[1, '1024x768_87i'],
		[1, '1024x768_60'],
		[1, '1024x768_70'],
		[1, '1024x768_75'],
		[1, '1280x1024_75'],
		# byte 3, 25h
		# 7: [1, '1152x870_75'], # apple macII
		# 6-0: manufacturer's timings
	],
	detailed_timing => [
		[8, 'horizontal_active'],
		[8, 'horizontal_blanking'],
		[4, 'horizontal_active_hi'],
		[4, 'horizontal_blanking_hi'],
		[8, 'vertical_active'],
		[8, 'vertical_blanking'],
		[4, 'vertical_active_hi'],
		[4, 'vertical_blanking_hi'],
		[8, 'horizontal_sync_offset'],
		[8, 'horizontal_sync_pulse_width'],
		[4, 'vertical_sync_offset'],
		[4, 'vertical_sync_pulse_width'],
		[2, 'horizontal_sync_offset_hi'],
		[2, 'horizontal_sync_pulse_width_hi'],
		[2, 'vertical_sync_offset_hi'],
		[2, 'vertical_sync_pulse_width_hi'],
		[8, 'horizontal_image_size'], # in mm
		[8, 'vertical_image_size'], # in mm
		[4, 'horizontal_image_size_hi'],
		[4, 'vertical_image_size_hi'],
		[8, 'horizontal_border'],
		[8, 'vertical_border'],
		[1, 'interlaced'],
		[2, 'stereo'],	  
		[2, 'digital_composite'],
		[1, 'horizontal_sync_positive'],
		[1, 'vertical_sync_positive'],
		[1, ''],
	],
	# 16 bytes, up to 8 additional timings, each identified by a unique 2 byte 
	# code derived from the horizontal active pixel count, the image aspect ratio 
	# and field refresh rate as described in Table 3.19
	standard_timing => [
		[8, 'X'],
		[2, 'aspect'],
		[6, 'vfreq'],
	],
	monitor_range => [
		[8, 'vertical_min'],
		[8, 'vertical_max'],
		[8, 'horizontal_min'],
		[8, 'horizontal_max'],
		[8, 'pixel_clock_max'],
	],
	manufacturer_specified_range_timing => [
		# http://www.spwg.org/salisbury_march_19_2002.pdf
		# for the glossary: http://www.vesa.org/Public/PSWG/PSWG15v1.pdf
		[8, 'horizontal_sync_pulse_width_min'], # HSPW (Horizontal Sync Pulse Width)
		[8, 'horizontal_sync_pulse_width_max'],
		[8, 'horizontal_back_porch_min'], # t_hbp
		[8, 'horizontal_back_porch_max'],
		[8, 'vertical_sync_pulse_width_min'], # VSPW (Vertical Sync Pulse Width)
		[8, 'vertical_sync_pulse_width_max'],
		[8, 'vertical_back_porch_min'], # t_vbp (Vertical Back Porch)
		[8, 'vertical_back_porch_max'],
		[8, 'horizontal_blanking_min'], # t_hp (Horizontal Period)
		[8, 'horizontal_blanking_max'],
		[8, 'vertical_blanking_min'], # t_vp
		[8, 'vertical_blanking_max'],
		[8, 'module_revision'],
	],
	cea_data_block_collection => [
		[3, 'type'],
		[5, 'size'],
	],
	cea_video_data_block => [
		[1, 'native'],
		[7, 'mode'],
	],
	# Section 3.7 in VESA-EEDID-A2.pdf specs
	color_characteristics => [
		# Rx1 Rx0 Ry1 Ry0 Gx1 Gx0 Gy1 Gy0
		[8, 'white_point_red_green'],
		# Bx1 Bx0 By1 By0 Wx1 Wx0 Wy1 Wy0
		[8, 'white_point_blue_white'],
		[8, 'red_x'],
		[8, 'red_y'],
		[8, 'green_x'],
		[8, 'green_y'],
		[8, 'blue_x'],
		[8, 'blue_y'],
		[8, 'white_x'],
		[8, 'white_y'],
	],
);
my @cea_video_mode_to_detailed_timing = (
	'pixel_clock',
	'horizontal_active',
	'vertical_active',
	'aspect',
	'horizontal_blanking',
	'horizontal_sync_offset',
	'horizontal_sync_pulse_width',
	'vertical_blanking',
	'vertical_sync_offset',
	'vertical_sync_pulse_width',
	'horizontal_sync_positive',
	'vertical_sync_positive',
	'interlaced'
);
my @cea_video_modes = (
# [0] pixel clock, [1] X, [2] Y, [3] aspect, [4] Hblank, [5] Hsync_offset, [6] Hsync_pulse_width,
# [7] Vblank, [8] Vsync_offset, [9] Vsync_pulse_width, [10] Hsync+, [11] Vsync+, [12] interlaced
# 59.94/29.97 and similar modes also have a 60.00/30.00 counterpart by raising the pixel clock
	[  25.175,  640,  480,  "4/3",  160,   16,  96,  45, 10,  2, 0, 0, 0 ], #  1:  640x 480@59.94
	[  27.000,  720,  480,  "4/3",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], #  2:  720x 480@59.94
	[  27.000,  720,  480, "16/9",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], #  3:  720x 480@59.94
	[  74.250, 1280,  720, "16/9",  370,  110,  40,  30,  5,  5, 1, 1, 0 ], #  4: 1280x 720@60.00
	[  74.250, 1920, 1080, "16/9",  280,   88,  44,  45,  4, 10, 1, 1, 1 ], #  5: 1920x1080@30.00
	[  27.000, 1440,  480,  "4/3",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], #  6: 1440x 480@29.97
	[  27.000, 1440,  480, "16/9",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], #  7: 1440x 480@29.97
	[  27.000, 1440,  240,  "4/3",  276,   38, 124,  22,  4,  3, 0, 0, 0 ], #  8: 1440x 240@60.05
	[  27.000, 1440,  240, "16/9",  276,   38, 124,  22,  4,  3, 0, 0, 0 ], #  9: 1440x 240@60.05
	[  54.000, 2880,  480,  "4/3",  552,   76, 248,  45,  8,  6, 0, 0, 1 ], # 10: 2880x 480@29.97
	[  54.000, 2880,  480, "16/9",  552,   76, 248,  45,  8,  6, 0, 0, 1 ], # 11: 2880x 480@29.97
	[  54.000, 2880,  240,  "4/3",  552,   76, 248,  22,  4,  3, 0, 0, 0 ], # 12: 2880x 240@60.05
	[  54.000, 2880,  240, "16/9",  552,   76, 248,  22,  4,  3, 0, 0, 0 ], # 13: 2880x 240@60.05
	[  54.000, 1440,  480,  "4/3",  276,   32, 124,  45,  9,  6, 0, 0, 0 ], # 14: 1440x 480@59.94
	[  54.000, 1440,  480, "16/9",  276,   32, 124,  45,  9,  6, 0, 0, 0 ], # 15: 1440x 480@59.94
	[ 148.500, 1920, 1080, "16/9",  280,   88,  44,  45,  4,  5, 1, 1, 0 ], # 16: 1920x1080@60.00
	[  27.000,  720,  576,  "4/3",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 17:  720x 576@50.00
	[  27.000,  720,  576, "16/9",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 18:  720x 576@50.00
	[  74.250, 1280,  720, "16/9",  700,  440,  40,  30,  5,  5, 1, 1, 0 ], # 19: 1280x 720@50.00
	[  74.250, 1920, 1080, "16/9",  720,  528,  44,  45,  4, 10, 1, 1, 1 ], # 20: 1920x1080@25.00
	[  27.000, 1440,  576,  "4/3",  288,   24, 126,  49,  4,  6, 0, 0, 1 ], # 21: 1440x 576@25.00
	[  27.000, 1440,  576, "16/9",  288,   24, 126,  49,  4,  6, 0, 0, 1 ], # 22: 1440x 576@25.00
	[  27.000, 1440,  288,  "4/3",  288,   24, 126,  24,  2,  3, 0, 0, 0 ], # 23: 1440x 288@50.08
	[  27.000, 1440,  288, "16/9",  288,   24, 126,  24,  2,  3, 0, 0, 0 ], # 24: 1440x 288@50.08
	[  54.000, 2880,  576,  "4/3",  576,   48, 252,  49,  4,  6, 0, 0, 1 ], # 25: 2880x 576@25.00
	[  54.000, 2880,  576, "16/9",  576,   48, 252,  49,  4,  6, 0, 0, 1 ], # 26: 2880x 576@25.00
	[  54.000, 2880,  288,  "4/3",  576,   48, 252,  24,  2,  3, 0, 0, 0 ], # 27: 2880x 288@50.08
	[  54.000, 2880,  288, "16/9",  576,   48, 252,  24,  2,  3, 0, 0, 0 ], # 28: 2880x 288@50.08
	[  54.000, 1440,  576,  "4/3",  288,   24, 128,  49,  5,  5, 0, 0, 0 ], # 29: 1440x 576@50.00
	[  54.000, 1440,  576, "16/9",  288,   24, 128,  49,  5,  5, 0, 0, 0 ], # 30: 1440x 576@50.00
	[ 148.500, 1920, 1080, "16/9",  720,  528,  44,  45,  4,  5, 1, 1, 0 ], # 31: 1920x1080@50.00
	[  74.250, 1920, 1080, "16/9",  830,  638,  44,  45,  4,  5, 1, 1, 0 ], # 32: 1920x1080@24.00
	[  74.250, 1920, 1080, "16/9",  720,  528,  44,  45,  4,  5, 1, 1, 0 ], # 33: 1920x1080@25.00
	[  74.250, 1920, 1080, "16/9",  280,   88,  44,  45,  4,  5, 1, 1, 0 ], # 34: 1920x1080@30.00
	[ 108.000, 2880,  480,  "4/3",  552,   64, 248,  45,  9,  6, 0, 0, 0 ], # 35: 2880x 480@59.94
	[ 108.000, 2880,  480, "16/9",  552,   64, 248,  45,  9,  6, 0, 0, 0 ], # 36: 2880x 480@59.94
	[ 108.000, 2880,  576,  "4/3",  576,   48, 256,  49,  5,  5, 0, 0, 0 ], # 37: 2880x 576@50.00
	[ 108.000, 2880,  576, "16/9",  576,   48, 256,  49,  5,  5, 0, 0, 0 ], # 38: 2880x 576@50.00
	[  72.000, 1920, 1080, "16/9",  384,   32, 168, 170, 46, 10, 1, 0, 1 ], # 39: 1920x1080@25.00
	[ 148.500, 1920, 1080, "16/9",  720,  528,  44,  45,  4, 10, 1, 1, 1 ], # 40: 1920x1080@50.00
	[ 148.500, 1280,  720, "16/9",  700,  440,  40,  30,  5,  5, 1, 1, 0 ], # 41: 1280x 720@100.00
	[  54.000,  720,  576,  "4/3",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 42:  720x 576@100.00
	[  54.000,  720,  576, "16/9",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 43:  720x 576@100.00
	[  54.000, 1440,  576,  "4/3",  288,   24, 126,  49,  4,  6, 0, 0, 0 ], # 44: 1440x 576@50.00
	[  54.000, 1440,  576, "16/9",  288,   24, 126,  49,  4,  6, 0, 0, 0 ], # 45: 1440x 576@50.00
	[ 148.500, 1920, 1080, "16/9",  280,   88,  44,  45,  4, 10, 1, 1, 1 ], # 46: 1920x1080@60.00
	[ 148.500, 1280,  720, "16/9",  370,  110,  40,  30,  5,  5, 1, 1, 0 ], # 47: 1280x 720@120.00
	[  54.000,  720,  480,  "4/3",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], # 48:  720x 480@119.88
	[  54.000,  720,  480, "16/9",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], # 49:  720x 480@119.88
	[  54.000, 1440,  480,  "4/3",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], # 50: 1440x 480@59.94
	[  54.000, 1440,  480, "16/9",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], # 51: 1440x 480@59.94
	[ 108.000,  720,  576,  "4/3",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 52:  720x 576@200.00
	[ 108.000,  720,  576, "16/9",  144,   12,  64,  49,  5,  5, 0, 0, 0 ], # 53:  720x 576@200.00
	[ 108.000, 1440,  576,  "4/3",  288,   24, 126,  49,  4,  6, 0, 0, 1 ], # 54: 1440x 576@100.00
	[ 108.000, 1440,  576, "16/9",  288,   24, 126,  49,  4,  6, 0, 0, 1 ], # 55: 1440x 576@100.00
	[ 108.000,  720,  480,  "4/3",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], # 56:  720x 480@239.76
	[ 108.000,  720,  480, "16/9",  138,   16,  62,  45,  9,  6, 0, 0, 0 ], # 57:  720x 480@239.76
	[ 108.000, 1440,  480,  "4/3",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], # 58: 1440x 480@119.88
	[ 108.000, 1440,  480, "16/9",  276,   38, 124,  45,  8,  6, 0, 0, 1 ], # 59: 1440x 480@119.88
	[  59.400, 1280,  720, "16/9", 2020, 1760,  40,  30,  5,  5, 1, 1, 0 ], # 60: 1280x 720@24.00
	[  74.250, 1280,  720, "16/9", 2680, 2420,  40,  30,  5,  5, 1, 1, 0 ], # 61: 1280x 720@25.00
	[  74.250, 1280,  720, "16/9", 2020, 1760,  40,  30,  5,  5, 1, 1, 0 ], # 62: 1280x 720@30.00
	[ 297.000, 1920, 1080, "16/9",  280,   88,  44,  45,  4,  5, 1, 1, 0 ], # 63: 1920x1080@120.00
	[ 297.000, 1920, 1080, "16/9",  720,  528,  44,  45,  4, 10, 1, 1, 0 ], # 64: 1920x1080@100.00
);
# Exist but IDs Unknown: Pixio, AOpen (AON?), AORUS [probably GBT], Deco Gear, 
# Eyoyo, GAEMS, GeChic, KOORUI, Lilliput, Mobile Pixels, Nexanic, SunFounder,
# TECNII, TPEKKA, V7/VSEVEN, 
# Guesses: KYY=KYY, MSI=MSI, KOE=Kaohsiung Opto Electronics
# PGS: Princeton Graphic Systems; SDC: Samsung Display Co; 
# SIS: Silicon Integrated Systems; STN: Samsung Electronics America; 
# BDS: Barco Display Systems
# TAI: Toshiba America
# HIQ: Hitachi ImageQuest or Kaohsiung Opto Electronics? or does Imagequest make hitachi:
# NVD: Nvidia or NewVisionDisplay?
my %vendors = (
'AAC' => 'AcerView', 'ACI' => 'Asus', 'ACR' => 'Acer', 'ACT' => 'Targa', 'ADI' => 'ADI', 
'AIC' => 'AG Neovo', 'AMW' => 'AMW', 'ANX' => 'Acer Netxix', 'AOC' => 'AOC', 'API' => 'A Plus Info', 
'APP' => 'Apple', 'ART' => 'ArtMedia', 'AST' => 'AST Research', 'AUO' => 'AU Optronics', 
'BEL' => 'Beltronic', 'BMM' => 'BMM', 'BNQ' => 'BenQ', 'BOE' => 'BOE Display', 'BDS' => 'Barco',
'CHO' => 'Sichuang Changhong', 'CMN' => 'ChiMei InnoLux', 'CMO' => 'Chi Mei Optoelectronics', 
'CPL' => 'Compal/ALFA', 'CPQ' => 'Compaq', 'CPT' => 'Chungwa Picture Tubes', 'CTX' => 'CTX (Chuntex)', 'CVT' => 'DGM', 
'DEC' => 'DEC', 'DEL' => 'Dell', 'DON' => 'Denon', 'DPC' => 'Delta', 'DPL' => 'Digital Projection', 'DWE' => 'Daewoo', 
'ECS' => 'Elitegroup', 'EIZ' => 'EIZO', 'ELS' => 'ELSA', 'ENC' => 'EIZO NANAO', 'EPI' => 'Envision', 'ETR' => 'Rotel', 
'FCM' => 'Funai', 'FUJ' => 'Fujitsu', 'FUS' => 'Fujitsu Siemens', 
'GBT' => 'Gigabyte', 'GFN' => 'Gefen', 'GSM' => 'LG (GoldStar)', 'GWY' => 'Gateway 2000',
'HEI' => 'Hyundai.', 'HIQ' => 'Hyundai ImageQuest', 'HIT' => 'Hitachi', 'HPN' => 'HP', 
'HSD' => 'HannSpree/HannStar', 'HSL' => 'Hansol', 'HTC' => 'Hitachi/Nissei', 'HVR' => 'Hitachi', 
'HWP' => 'HP', 'HWV' => 'Huawei',
'IBM' => 'IBM', 'ICL' => 'Fujitsu ICL', 'IFS' => 'InFocus', 'INO' => 'Innolab Pte', 'IQT' => 'Hyundai', 
'IVM' => 'Idek Iiyama', 'IVO' => 'InfoVision Optronics/Kunshan', 
'KDS' => 'Korea Data Systems (KDS)', 'KFC' => 'KFC Computek', 'KOE' => 'Kaohsiung OptoElectronics', 
'KTC' => 'Kingston', 'KYY' => 'KYY', 
'LCD' => 'Toshiba Matsushita', 'LEN' => 'Lenovo', 'LGD' => 'LG Display', 'LKM' => 'Adlas/Azalea', 
'LNK' => 'LINK', 'LPL' => 'LG Philips', 'LTN' => 'Lite-On', 
'MAG' => 'MAG InnoVision', 'MAX' => 'Belinea/Maxdata', 'MED' => 'Medion', 
'MEI' => 'Panasonic', 'MEL' => 'Mitsubishi', 'MIR' => 'Miro', 'MSI' => 'MSI', 'MTC' => 'MITAC', 
'NAN' => 'NANAO/EIZO', 'NEX' => 'Nexgen Mediatech', 'NCP' => 'Najing CEC Panda', 'NEC' => 'NEC', 
'NOK' => 'Nokia', 'NVD' => 'Nvidia', 
'ONK' => 'Onkyo',  'OPT' => 'Optoma','OQI' => 'ViewSonic Optiquest', 'ORN' => 'Orion',
'PBN' => 'Packard Bell', 'PCK' => 'Daewoo', 'PDC' => 'Polaroid', 'PGS' => 'Princeton', 
'PHL' => 'Philips', 'PIO' => 'Pioneer', 'PNR' => 'Planar', 'PRT' => 'Princeton', 
'QDI' => 'Quantum Data', 'QDS' => 'Quanta Display', 'REL' => 'Relisys', 'REN' => 'Renesas',
'SAM' => 'Samsung', 'SAN' => 'Sanyo', 'SBI' => 'Smarttech', 'SDC' => 'Samsung', 'SEC' => 'Seiko Epson', 
'SEN' => 'Sensics', 'SHP' => 'Sharp', 'SGD' => 'Sigma Designs', 'SGI' => 'SGI', 'SHI' => 'Jiangsu Shinco', 
'SII' => 'Silicon Image', 'SIS' => 'SIS', 'SKM' => 'Guangzhou Teclast', 'SMC' => 'Samtron', 
'SMI' => 'Smile', 'SNI' => 'Siemens Nixdorf', 'SNY' => 'Sony', 'SPT' => 'Sceptre', 
'SRC' => 'Shamrock', 'STN' => 'Samsung', 'STP' => 'Sceptre', 'SUN' => 'Sun Microsystems', 'SYN' => 'Synaptics',
'TAI' => 'Toshiba', 'TAT' => 'Tatung', 'TOS' => 'Toshiba', 'TRL' => 'Royal Information', 
'TSB' => 'Toshiba', 'UEG' => 'EliteGroup', 'UNM' => 'Unisys', 
'VIT' => 'Visitech', 'VLV' => 'Valve', 'VSC' => 'ViewSonic', 'VTK' => 'Viewteck', 'VTS' => 'VTech',
'WTC' => 'Wen Technology', 'XLX' => 'Xilinx', 'YMH' => 'Yamaha', 'ZCM' => 'Zenith',
);

sub _within_limit {
	my ($value, $type, $limit) = @_;
	$type eq 'min' ? $value >= $limit : $value <= $limit;
}

sub _get_many_bits {
	my ($s, $field_name) = @_;
	my @bits = split('', unpack('B*', $s));
	my %h;
	foreach (@{$subfields{$field_name}}) {
		my ($size, $field) = @$_;
		my @l = ('0' x (8 - $size), splice(@bits, 0, $size));
		if ($field && $field !~ /^_/){
			$h{$field} = unpack("C", pack('B*', join('', @l)));
			# spec: chromacity: 0.xyz: white_point see color_characteristics
			if ($h{$field} && $field_name eq 'color_characteristics'){
				$h{$field} = ($field =~ /_[xy]$/) ? sprintf('%0.3f',$h{$field}/255) : [@l[1..8]];
			}
		}
	}
	\%h;
}

sub _build_detailed_timing {
	my ($pixel_clock, $vv) = @_;
	my $h = _get_many_bits($vv, 'detailed_timing');
	$h->{pixel_clock} = $pixel_clock / 100; # to have it in MHz
	my %detailed_timing_field_size = map { $_->[1], $_->[0] } @{$subfields{detailed_timing}};
	foreach my $field (keys %detailed_timing_field_size) {
		$field =~ s/_hi$// or next;
		my $hi = delete($h->{$field . '_hi'});
		$h->{$field} += $hi << $detailed_timing_field_size{$field};
	}
	$h;
}

sub _add_standard_timing_modes {
	my ($edid, $v) = @_;
	my @aspect2ratio = (
		$edid->{edid_version} > 1 || $edid->{edid_revision} > 2 ? '16/10' : '1/1',
		'4/3', '5/4', '16/9',
	);
	$v = [ map {
		my $h = _get_many_bits($_, 'standard_timing');
		$h->{X} = ($h->{X} + 31) * 8;
		if ($_ ne "\x20\x20" && $h->{X} > 256){ # cf VALID_TIMING in Xorg edid.h
			$h->{vfreq} += 60;
			if ($h->{ratio} = $aspect2ratio[$h->{aspect}]){
				delete $h->{aspect};
				$h->{Y} = $h->{X} / eval($h->{ratio});
			}
			$h;
		} 
		else { () }
	} unpack('a2' x (length($v) / 2), $v) ];
	$v;
}

sub parse_edid {
	eval $start if $b_log;
	my ($raw_edid, $verbose) = @_;
	my (%edid, @warnings);
	my ($main_edid, @eedid_blocks) = unpack("a128" x (length($raw_edid) / 128), $raw_edid);
	my @vals = unpack(join('', map { $_->[0] } @edid_info), $main_edid);
	my $i = 0;
	foreach (@edid_info) {
		my ($field, $v) = ($_->[1], $vals[$i++]);
		if ($field eq 'year'){
			$v += 1990;
		} 
		elsif ($field eq 'manufacturer_name'){
			my $h = _get_many_bits($v, 'manufacturer_name');
			$v = join('', map { chr(ord('A') + $h->{$_} - 1) } 1 .. 3);
			$v = "" if $v eq "@@@";
			$edid{'manufacturer_name_nice'} = ($v && $vendors{$v}) ? $vendors{$v} : ''; 
		} 
		elsif ($field eq 'video_input_definition'){
			$v = _get_many_bits($v, 'video_input_definition');
		}
		elsif ($field eq 'feature_support'){
			$v = _get_many_bits($v, 'feature_support');
		} 
		elsif ($field eq 'color_characteristics'){
			$v = _get_many_bits($v, 'color_characteristics');
		}
		elsif ($field eq 'established_timings'){
			my $h = _get_many_bits($v, 'established_timings');
			$v = [
				sort { $a->{X} <=> $b->{X} || $a->{vfreq} <=> $b->{vfreq} }
				map { /(\d+)x(\d+)_(\d+)(i?)/ ? { X => $1, Y => $2, vfreq => $3, $4 ? (interlace => 1) : () } : () }
				grep { $h->{$_} } keys %$h ];
		} 
		elsif ($field eq 'standard_timings'){
			$v = _add_standard_timing_modes(\%edid, $v);
		} 
		elsif ($field eq 'monitor_details'){
			while ($v){
				(my $pixel_clock, my $vv, $v) = unpack("v a16 a*", $v);
				if ($pixel_clock){
					# detailed timing
					my $h = _build_detailed_timing($pixel_clock, $vv);
					push @{$edid{detailed_timings}}, $h
					  if $h->{horizontal_active} > 1 && $h->{vertical_active} > 1;
				}
				else {
					(my $flag, $vv) = unpack("n x a*", $vv);
					if ($flag == 0xfd){
						# range
						$edid{monitor_range} = _get_many_bits($vv, 'monitor_range');
						if ($edid{monitor_range}{pixel_clock_max} == 0xff){
							delete $edid{monitor_range}{pixel_clock_max};
						} 
						else {
							$edid{monitor_range}{pixel_clock_max} *= 10; #- to have it in MHz
						}
					} 
					elsif ($flag == 0xf){
						my $range = _get_many_bits($vv, 'manufacturer_specified_range_timing');
						my $e = $edid{detailed_timings}[0];
						my $valid = 1;
						foreach my $m ('min', 'max') {
							my %total;
							foreach my $dir ('horizontal', 'vertical'){
								$range->{$dir . '_sync_pulse_width_' . $m} *= 2;
								$range->{$dir . '_back_porch_' . $m} *= 2;
								$range->{$dir . '_blanking_' . $m} *= 2;
								if ($e && $e->{$dir . '_active'}
									&& _within_limit($e->{$dir . '_blanking'}, $m, $range->{$dir . '_blanking_' . $m})
									&& _within_limit($e->{$dir . '_sync_pulse_width'}, $m, $range->{$dir . '_sync_pulse_width_' . $m})
									&& _within_limit($e->{$dir . '_blanking'} - $e->{$dir . '_sync_offset'} - $e->{$dir . '_sync_pulse_width'},
											$m, $range->{$dir . '_back_porch_' . $m})){
									$total{$dir} = $e->{$dir . '_active'} + $range->{$dir . '_blanking_' . $m};
								}
							}
							if ($total{horizontal} && $total{vertical}){
								my $hfreq = $e->{pixel_clock} * 1000 / $total{horizontal};
								my $vfreq = $hfreq * 1000 / $total{vertical};
								$range->{'horizontal_' . ($m eq 'min' ? 'max' : 'min')} = _round($hfreq);
								$range->{'vertical_' . ($m eq 'min' ? 'max' : 'min')} = _round($vfreq);
							} 
							else {
								$valid = 0;
							}
						}
						$edid{$valid ? 'monitor_range' : 'manufacturer_specified_range_timing'} = $range;
					} 
					elsif ($flag == 0xfa){
						push @{$edid{standard_timings}}, _add_standard_timing_modes(\%edid, unpack('a12', $vv));
					} 
					elsif ($flag == 0xfc){
						my $prev = $edid{monitor_name};
						$edid{monitor_name} = ($prev ? "$prev " : '') . unpack('A13', $vv);
					} 
					elsif ($flag == 0xfe){
						push @{$edid{monitor_text}}, unpack('A13', $vv);
					} 
					elsif ($flag == 0xff){
						push @{$edid{serial_number2}}, unpack('A13', $vv);
					} 
					elsif ($vv ne "\0" x 13 && $vv ne " " x 13){
						push(@warnings, "parse_edid: unknown flag $flag");
						warn "$warnings[-1]\n" if $verbose;
					}
				}
			}
		}
		$edid{$field} = $v if $field && $field !~ /^_/;
	}
	foreach (@eedid_blocks){
		my ($tag, $v) = unpack("C a*", $_);
		if ($tag == 0x02){ # CEA EDID
			my $dtd_offset;
			($dtd_offset, $v) = unpack("x C x a*", $v);
			next if $dtd_offset < 4;
			$dtd_offset -= 4;
			while ($dtd_offset > 0){
				if (!$v){
					push(@warnings, "parse_edid: DTD offset outside of available data");
					warn "$warnings[-1]\n" if $verbose;
					last;
				}
				my $h = _get_many_bits($v, 'cea_data_block_collection');
				$dtd_offset -= $h->{size} + 1;
				my $vv;
				($vv, $v) = unpack("x a$h->{size} a*", $v);
				if ($h->{type} == 0x02){ # Video Data Block
					my @vmodes = unpack("a" x $h->{size}, $vv);
					foreach my $vmode (@vmodes){
						$h = _get_many_bits($vmode, 'cea_video_data_block');
						my $cea_mode = $cea_video_modes[$h->{mode} - 1];
						if (!$cea_mode){
							push(@warnings, "parse_edid: unhandled CEA mode $h->{mode}");
							warn "$warnings[-1]\n" if $verbose;
							next;
						}
						my %det_mode = (source => 'cea_vdb');
						@det_mode{@cea_video_mode_to_detailed_timing} = @$cea_mode;
						push @{$edid{detailed_timings}}, \%det_mode;
					}
				}
			}
			while (length($v) >= 18){
				(my $pixel_clock, my $vv, $v) = unpack("v a16 a*", $v);
				last if !$pixel_clock;
				my $h = _build_detailed_timing($pixel_clock, $vv);
				push @{$edid{detailed_timings}}, $h
					if $h->{horizontal_active} > 1 && $h->{vertical_active} > 1;
			}
		} 
		else {
			 push(@warnings, "parse_edid: unknown tag $tag");
       warn "$warnings[-1]\n" if $verbose;
		}
	}
	$edid{max_size_precision} = 'cm';
	if ($edid{product_code}){
		$edid{product_code_h} = sprintf('%04x', $edid{product_code});
		if ($edid{manufacturer_name}){
			$edid{EISA_ID} = $edid{manufacturer_name} . $edid{product_code_h};
		}
		$edid{product_code_h} = '0x'. $edid{product_code_h};
	}
	if ($edid{monitor_range}){
		$edid{HorizSync} = $edid{monitor_range}{horizontal_min} . '-' . $edid{monitor_range}{horizontal_max};
		$edid{VertRefresh} = $edid{monitor_range}{vertical_min} . '-' . $edid{monitor_range}{vertical_max};
	}
	if ($edid{max_size_vertical}){
		$edid{ratio} = $edid{max_size_horizontal} / $edid{max_size_vertical};
		$edid{ratio_name} = _ratio_name($edid{max_size_horizontal}, $edid{max_size_vertical}, 'cm');
		$edid{ratio_precision} = 'cm';
	}
	if ($edid{feature_support}{has_preferred_timing} && $edid{detailed_timings}[0]){
		$edid{detailed_timings}[0]{preferred} = 1;
	}
	foreach my $h (@{$edid{detailed_timings}}){
		# EDID standard is ambiguous on how interlaced modes should be
		# specified; workaround clearly broken modes:
		if ($h->{interlaced}){
			foreach ("720x480", "1440x480", "2880x480", "720x576", "1440x576", "2880x576", "1920x1080"){
				if ($_ eq $h->{horizontal_active} . 'x' . $h->{vertical_active} * 2){
					$h->{vertical_active} *= 2;
					$h->{vertical_blanking} *= 2;
					$h->{vertical_sync_offset} *= 2;
					$h->{vertical_sync_pulse_width} *= 2;
					$h->{vertical_blanking} |= 1;
				}
			}
		}
		# if the mm size given in the detailed_timing is not far from the cm size
		# put it as a more precise cm size
		my %in_cm = (
			horizontal => _define($h->{horizontal_image_size}) / 10,
			vertical   => _define($h->{vertical_image_size}) / 10,
		);
		my ($error) = sort { $b <=> $a } map { abs($edid{'max_size_' . $_} - $in_cm{$_}) } keys %in_cm;
		if ($error <= 0.5){
			$edid{'max_size_' . $_} = $in_cm{$_} foreach keys %in_cm;
			$edid{max_size_precision} = 'mm';
		}
		if ($error < 1 && $in_cm{vertical}){
			# using it for the ratio
			$edid{ratio} = $in_cm{horizontal} / $in_cm{vertical};
			$edid{ratio_name} = _ratio_name($in_cm{horizontal}, $in_cm{vertical}, 'mm');
			$edid{ratio_precision} = 'mm';
		}
		if ($edid{ratio_precision} &&
		abs($edid{ratio} - $h->{horizontal_active} / $h->{vertical_active}) > ($edid{ratio_precision} eq 'mm' ? 0.02 : 0.2)){
			$h->{bad_ratio} = 1;
		}
		if ($edid{ratio_name}){
			$edid{ratios} = $edid{ratio_name};
			$edid{ratios} =~ s|/|:|g;
			$edid{ratios} = [split(/ or /, $edid{ratios})]; # "3/2 or 16/10"
		}
		if ($edid{max_size_vertical}){
			$h->{vertical_dpi} = $h->{vertical_active} / $edid{max_size_vertical} * 2.54;
		}
		if ($edid{max_size_horizontal}){
			$h->{horizontal_dpi} = $h->{horizontal_active} / $edid{max_size_horizontal} * 2.54;
		}
		if ($h->{horizontal_image_size}){
			$h->{horizontal_image_size_i} = sprintf('%.2f',($h->{horizontal_image_size}/25.4)) + 0;
		}
		if ($h->{vertical_image_size}){
			$h->{vertical_image_size_i} = sprintf('%.2f',($h->{vertical_image_size}/25.4)) + 0;
		}
		my $dpi_string = '';
		if ($h->{vertical_dpi} && $h->{horizontal_dpi}){
			$dpi_string = 
			  abs($h->{vertical_dpi} / $h->{horizontal_dpi} - 1) < 0.05 ? 
				sprintf("%d dpi", $h->{horizontal_dpi}) :
				sprintf("%dx%d dpi", $h->{horizontal_dpi}, $h->{vertical_dpi});
		}
		my $horizontal_total = $h->{horizontal_active} + $h->{horizontal_blanking};
		my $vertical_total = $h->{vertical_active} + $h->{vertical_blanking};
		no warnings 'uninitialized';
		$h->{ModeLine_comment} = sprintf(qq(# Monitor %s%s modeline (%.1f Hz vsync, %.1f kHz hsync, %sratio %s%s)),
			$h->{preferred} ? "preferred" : "supported",
			$h->{source} eq 'cea_vdb' ? " CEA" : '',
			$h->{pixel_clock} / $horizontal_total / $vertical_total * 1000 * 1000 * ($h->{interlaced} ? 2 : 1),
			$h->{pixel_clock} / $horizontal_total * 1000,
			$h->{interlaced} ? "interlaced, " : '',
			_nearest_ratio($h->{horizontal_active} / $h->{vertical_active}, 0.01) || sprintf("%.2f", $h->{horizontal_active} / $h->{vertical_active}),
			$dpi_string ? ", $dpi_string" : '');
			
		$h->{ModeLine} = sprintf(qq("%dx%d" $h->{pixel_clock} %d %d %d %d %d %d %d %d %shsync %svsync%s),
			$h->{horizontal_active}, $h->{vertical_active},
			$h->{horizontal_active},
			$h->{horizontal_active} + $h->{horizontal_sync_offset}, 
			$h->{horizontal_active} + $h->{horizontal_sync_offset} + $h->{horizontal_sync_pulse_width},
			$horizontal_total,
			$h->{vertical_active},
			$h->{vertical_active} + $h->{vertical_sync_offset}, 
			$h->{vertical_active} + $h->{vertical_sync_offset} + $h->{vertical_sync_pulse_width},
			$vertical_total,
			$h->{horizontal_sync_positive} ? '+' : '-',
			$h->{vertical_sync_positive} ? '+' : '-',
			$h->{interlaced} ? ' Interlace' : '');
	}
	$edid{diagonal_size} = sqrt(_sqr($edid{max_size_horizontal}) + _sqr($edid{max_size_vertical})) / 2.54;
	# we want to use null data found tests so only return errors/warnings if 
	# %edid or if verbose, since then we want to know no matter what.
	if (%edid || $verbose){
		_edid_errors(\%edid);
		$edid{edid_warnings} = \@warnings if @warnings;
	}
	eval $end if $b_log;
	\%edid;
}

sub _edid_errors {
	my $edid = shift @_;
	if (!defined $edid->{edid_version}){
		_edid_error($edid,'edid-version','undefined');
	}
	elsif ($edid->{edid_version} < 1 || $edid->{edid_version} > 2){
		_edid_error($edid,'edid-version',$edid->{edid_version});
	}
	if (!defined $edid->{edid_revision}){
		_edid_error($edid,'edid-revision','undefined');
	}
	elsif ($edid->{edid_revision} == 0xff){
		_edid_error($edid,'edid-revision',$edid->{edid_revision});
	}
	if ($edid->{monitor_range}){
		if (!$edid->{monitor_range}{horizontal_min}){
			_edid_error($edid,'edid-sync','no horizontal');
		}
		elsif ($edid->{monitor_range}{horizontal_min} > $edid->{monitor_range}{horizontal_max}){
			_edid_error($edid,'edid-sync', 
			"bad horizontal values: min: $edid->{monitor_range}{horizontal_min} max: $edid->{monitor_range}{horizontal_max}");
		}
		if (!$edid->{monitor_range}{vertical_min}){
			_edid_error($edid,'edid-sync','no vertical');
		}
		elsif ($edid->{monitor_range}{vertical_min} > $edid->{monitor_range}{vertical_max}){
			_edid_error($edid,'edid-sync',
			"bad vertical values: min: $edid->{monitor_range}{vertical_min} max: $edid->{monitor_range}{vertical_max}");
		}
	}
}

sub _edid_error {
	my ($edid,$error,$data) = @_;
	$edid->{edid_errors} = [] if !$edid->{edid_errors};
	push(@{$edid->{edid_errors}},main::message($error,$data));
}

sub _nearest_ratio {
	my ($ratio, $max_error) = @_;
	my @sorted = 
	  sort { $a->[1] <=> $b->[1] }
		map { 
			my $error = abs($ratio - eval($_));
			$error > $max_error ? () : [ $_, $error ];
		} @known_ratios;
	$sorted[0][0];
}

sub _ratio_name {
	my ($horizontal, $vertical, $precision) = @_;
	if ($precision eq 'mm'){
		_nearest_ratio($horizontal / $vertical, 0.1);
	} 
	else {
		my $error = 0.5;
		my $ratio1 = _nearest_ratio(($horizontal + $error) / ($vertical - $error), 0.2);
		my $ratio2 = _nearest_ratio(($horizontal - $error) / ($vertical + $error), 0.2);
		$ratio1 && $ratio2 or return;
		if ($ratio1 eq $ratio2){
			$ratio1;
		} 
		else {
			my $ratio = _nearest_ratio($horizontal / $vertical, 0.2);
			join(' or ', $ratio, $ratio eq $ratio1 ? $ratio2 : $ratio1);
		}
	}
}

sub _define { 
	defined $_[0] ? $_[0] : 0;
}

sub _sqr {
	$_[0] * $_[0];
}

sub _round { 
	int($_[0] + 0.5);
}
}

## PartitionData: public methods: set(), get()
# for /proc/partitions only, see DiskDataBSD for BSD partition data.
{
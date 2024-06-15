package OptionsHandler;
# Note: used %trigger here, but perl 5.008 had issues, so mmoved to global. 
# Careful with hash globals in first Perl 5.0080.
my ($self_download,$download_id);

sub get {
	eval $start if $b_log;
	$show{'short'} = 1;
	Getopt::Long::GetOptions (
	'a|admin' => sub {
		$b_admin = 1;},
	'A|audio' => sub {
		$show{'short'} = 0;
		$show{'audio'} = 1;},
	'b|basic' => sub {
		$show{'short'} = 0;
		$show{'battery'} = 1;
		$show{'cpu-basic'} = 1;
		$show{'raid-basic'} = 1;
		$show{'disk-total'} = 1;
		$show{'graphic'} = 1;
		$show{'graphic-basic'} = 1;
		$show{'info'} = 1;
		$show{'machine'} = 1;
		$show{'network'} = 1;
		$show{'system'} = 1;},
	'B|battery' => sub {
		$show{'short'} = 0;
		$show{'battery'} = 1;
		$show{'battery-forced'} = 1;},
	'c|color:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg >= 0 && $arg < main::get_color_scheme('count')){
			main::set_color_scheme($arg);
		}
		elsif ($arg >= 94 && $arg <= 99){
			$colors{'selector'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'C|cpu' => sub {
		$show{'short'} = 0;
		$show{'cpu'} = 1;},
	'config|configs|configuration|configurations' => sub {
		$show{'configs'} = 1;},
	'd|disk-full|optical' => sub {
		$show{'short'} = 0;
		$show{'disk'} = 1;
		$show{'optical'} = 1;},
	'D|disk' => sub {
		$show{'short'} = 0;
		$show{'disk'} = 1;},
	'E|bluetooth' => sub {
		$show{'short'} = 0;
		$show{'bluetooth'} = 1; 
		$show{'bluetooth-forced'} = 1;},
	'edid' => sub {
		$b_admin = 1;
		$show{'short'} = 0;
		$show{'edid'} = 1;
		$show{'graphic'} = 1;
		$show{'graphic-full'} = 1;},
	'f|flags|flag' => sub {
		$show{'short'} = 0;
		$show{'cpu'} = 1;
		$show{'cpu-flag'} = 1;},
	'F|full' => sub {
		$show{'short'} = 0;
		$show{'audio'} = 1;
		$show{'battery'} = 1;
		$show{'bluetooth'} = 1;
		$show{'cpu'} = 1;
		$show{'disk'} = 1;
		$show{'graphic'} = 1;
		$show{'graphic-basic'} = 1;
		$show{'graphic-full'} = 1;
		$show{'info'} = 1;
		$show{'machine'} = 1;
		$show{'network'} = 1;
		$show{'network-advanced'} = 1;
		$show{'partition'} = 1;
		$show{'raid'} = 1;
		$show{'sensor'} = 1;
		$show{'swap'} = 1;
		$show{'system'} = 1;},
	'gpu|nvidia|nv' => sub {
		main::error_handler('option-removed', '--gpu/--nvidia/--nv','-Ga');},
	'G|graphics|graphic' => sub {
		$show{'short'} = 0;
		$show{'graphic'} = 1; 
		$show{'graphic-basic'} = 1;
		$show{'graphic-full'} = 1;},
	'h|help|?' => sub {
		$show{'help'} = 1;},
	'i|ip' => sub {
		$show{'short'} = 0;
		$show{'ip'} = 1;
		$show{'network'} = 1;
		$show{'network-advanced'} = 1;
		$use{'downloader'} = 1 if !main::check_program('dig');},
	'ip-limit|limit:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg != 0){
			$limit = $arg;
			$use{'ip-limit'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'I|info' => sub {
		$show{'short'} = 0;
		$show{'info'} = 1;},
	'j|swap|swaps' => sub {
		$show{'short'} = 0;
		$show{'swap'} = 1;},
	'J|usb' => sub {
		$show{'short'} = 0;
		$show{'usb'} = 1;},
	'l|labels|label' => sub {
		$show{'label'} = 1;},
	'L|logical|lvm' => sub {
		$show{'short'} = 0;
		$show{'logical'} = 1;},
	'm|memory' => sub {
		$show{'short'} = 0;
		$show{'ram'} = 1;},
	'memory-modules|mm' => sub {
		$show{'short'} = 0;
		$show{'ram'} = 1; 
		$show{'ram-modules'} = 1;},
	'memory-short|ms' => sub {
		$show{'short'} = 0;
		$show{'ram'} = 1; 
		$show{'ram-short'} = 1;},
	'M|machine' => sub {
		$show{'short'} = 0;
		$show{'machine'} = 1;},
	'n|network-advanced' => sub {
		$show{'short'} = 0;
		$show{'network'} = 1;
		$show{'network-advanced'} = 1;},
	'N|network' => sub {
		$show{'short'} = 0;
		$show{'network'} = 1;},
	'o|unmounted' => sub {
		$show{'short'} = 0;
		$show{'unmounted'} = 1;},
	'p|partition-full|partitions-full' => sub {
		$show{'short'} = 0;
		$show{'partition'} = 0;
		$show{'partition-full'} = 1;},
	'partition-sort|partitions-sort|ps:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg =~ /^(dev-base|fs|id|label|percent-used|size|uuid|used)$/){
			$show{'partition-sort'} = $arg;
			$use{'partition-sort'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'P|partition|partitions' => sub {
		$show{'short'} = 0;
		$show{'partition'} = 1;},
	'r|repos|repo' => sub {
		$show{'short'} = 0;
		$show{'repo'} = 1;},
	'R|raid' => sub {
		$show{'short'} = 0;
		$show{'raid'} = 1;
		$show{'raid-forced'} = 1;},
	's|sensors|sensor' => sub {
		$show{'short'} = 0;
		$show{'sensor'} = 1;},
	'sensors-default' => sub {
		$use{'sensors-default'} = 1;},
	'sensors-exclude:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			@sensors_exclude = split(/\s*,\s*/, $arg);
			$use{'sensors-exclude'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'sensors-use:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			@sensors_use = split(/\s*,\s*/, $arg);
			$use{'sensors-use'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'separator|sep:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			$sep{'s1-console'} = $arg;
			$sep{'s2-console'} = $arg;
			$sep{'s1-irc'} = $arg;
			$sep{'s2-irc'} = $arg;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'sleep:s' => sub {
		my ($opt,$arg) = @_;
		$arg ||= 0;
		if ($arg >= 0){
			$cpu_sleep = $arg;
			$use{'cpu-sleep'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'slots|slot' => sub {
		$show{'short'} = 0;
		$show{'slot'} = 1;},
	'S|system' => sub {
		$show{'short'} = 0;
		$show{'system'} = 1;},
	't|processes|process:s' => sub {
		my ($opt,$arg) = @_;
		$show{'short'} = 0;
		$arg ||= 'cm';
		my $num = $arg;
		$num =~ s/^[cm]+// if $num;
		if ($arg =~ /^([cm]+)([0-9]+)?$/ && (!$num || $num =~ /^\d+/)){
			$show{'process'} = 1;
			if ($arg =~ /c/){
				$show{'ps-cpu'} = 1;
			}
			if ($arg =~ /m/){
				$show{'ps-mem'} = 1;
			}
			$ps_count = $num if $num;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'u|uuid' => sub {
		$show{'uuid'} = 1;},
	'v|verbosity:i' => sub {
		my ($opt,$arg) = @_;
		$show{'short'} = 0;
		if ($arg =~ /^[0-8]$/){
			if ($arg == 0){
				$show{'short'} = 1;
			}
			if ($arg >= 1){
				$show{'cpu-basic'} = 1;
				$show{'disk-total'} = 1;
				$show{'graphic'} = 1;
				$show{'graphic-basic'} = 1;
				$show{'info'} = 1;
				$show{'system'} = 1;
			}
			if ($arg >= 2){
				$show{'battery'} = 1;
				$show{'disk-basic'} = 1;
				$show{'raid-basic'} = 1;
				$show{'machine'} = 1;
				$show{'network'} = 1;
			}
			if ($arg >= 3){
				$show{'network-advanced'} = 1;
				$show{'cpu'} = 1;
				$extra = 1;
			}
			if ($arg >= 4){
				$show{'disk'} = 1;
				$show{'partition'} = 1;
			}
			if ($arg >= 5){
				$show{'audio'} = 1;
				$show{'bluetooth'} = 1;
				$show{'graphic-full'} = 1;
				$show{'label'} = 1;
				$show{'optical-basic'} = 1;
				$show{'raid'} = 1;
				$show{'ram'} = 1;
				$show{'sensor'} = 1;
				$show{'swap'} = 1;
				$show{'uuid'} = 1;
			}
			if ($arg >= 6){
				$show{'optical'} = 1;
				$show{'partition-full'} = 1;
				$show{'unmounted'} = 1;
				$show{'usb'} = 1;
				$extra = 2;
			}
			if ($arg >= 7){
				$use{'downloader'} = 1 if !main::check_program('dig');
				$show{'battery-forced'} = 1;
				$show{'bluetooth-forced'} = 1;
				$show{'cpu-flag'} = 1;
				$show{'ip'} = 1;
				$show{'logical'} = 1;
				$show{'raid-forced'} = 1;
				$extra = 3;
			}
			if ($arg >= 8){
				$b_admin = 1;
				# $use{'downloader'} = 1; # only if weather
				$force{'pkg'} = 1;
				$show{'edid'} = 1;
				$show{'process'} = 1;
				$show{'ps-cpu'} = 1;
				$show{'ps-mem'} = 1;
				$show{'repo'} = 1;
				$show{'slot'} = 1;
				# $show{'weather'} = 1;
			}
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'V' => sub { 
		main::error_handler('option-deprecated', '-V','--version/--vf');
		$show{'version'} = 1;},
	'version|vf' => sub { 
		$show{'version'} = 1;},
	'version-short|vs' => sub { 
		$show{'version-short'} = 1;},
	'w|weather:s' => sub { 
		my ($opt,$arg) = @_;
		$show{'short'} = 0;
		$use{'downloader'} = 1;
		if ($use{'weather'}){
			$arg =~ s/\s//g if $arg;
			if ($arg){
				$show{'weather'} = 1;
				$show{'weather-location'} = $arg;
			}
			else {
				$show{'weather'} = 1;
			}
		}
		else {
			main::error_handler('distro-block', $opt);
		}},
	'W|weather-location:s' => sub { 
		main::error_handler('option-removed', '-W','-w/--weather [location]');},
	'ws|weather-source:s' => sub {
		my ($opt,$arg) = @_;
		# let api processor handle checks if valid, this
		# future proofs this
		if ($arg =~ /^[1-9]$/){
			$weather_source = $arg;
			$use{'weather-source'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'weather-unit|wu:s' => sub {
		my ($opt,$arg) = @_;
		$arg ||= '';
		$arg =~ s/\s//g;
		$arg = lc($arg) if $arg;
		if ($arg && $arg =~ /^(c|f|cf|fc|i|m|im|mi)$/){
			my %units = ('c'=>'m','f'=>'i','cf'=>'mi','fc'=>'im');
			$arg = $units{$arg} if defined $units{$arg};
			$weather_unit = $arg;
			$use{'weather-unit'} = 1;
		}
		else {
			main::error_handler('bad-arg',$opt,$arg);
		}},
	'x|extra:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg > 0){
			$extra = $arg;
		}
		else {
			$extra++;
		}},
	'y|width:i' => sub {
		my ($opt, $arg) = @_;
		if (defined $arg && $arg == -1){
			$arg = 2000;
		}
		# note: :i creates 0 value if not supplied even though means optional
		elsif (!$arg){
			$arg = 80;
		}
		if ($arg =~ /\d/ && ($arg == 1 || $arg >= 60)){
			$size{'max-cols-basic'} = $arg if $arg != 1;
			$size{'max-cols'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'Y|height|less:i' => sub {
		my ($opt, $arg) = @_;
		main::error_handler('not-in-irc', '-Y/--height') if $b_irc;
		if ($arg >= -3){
			if ($arg >= 0){
				$size{'max-lines'} = ($arg) ? $arg: $size{'term-lines'};
			}
			elsif ($arg == -1) {
				$use{'output-block'} = 1;
			}
			elsif ($arg == -2) {
				$force{'colors'} = 1;
			}
			# unset conifiguration set max height
			else {
				$size{'max-lines'} = 0;
			}
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'z|filter' => sub {
		$use{'filter'} = 1;},
	'filter-all|za' => sub {
		$use{'filter'} = 1;
		$use{'filter-label'} = 1;
		$use{'filter-uuid'} = 1;
		$use{'filter-vulnerabilities'} = 1;},
	'filter-label|zl' => sub {
		$use{'filter-label'} = 1;},
	'Z|filter-override|no-filter' => sub {
		$use{'filter-override'} = 1;},
	'filter-uuid|zu' => sub {
		$use{'filter-uuid'} = 1;},
	'filter-v|filter-vulnerabilities|zv' => sub {
		$use{'filter-vulnerabilities'} = 1;},
	## Start non data options
	'alt:i' => sub { 
		my ($opt,$arg) = @_;
		if ($arg == 40){
			$dl{'tiny'} = 0;
			$use{'downloader'} = 1;}
		elsif ($arg == 41){
			$dl{'curl'} = 0;
			$use{'downloader'} = 1;}
		elsif ($arg == 42){
			$dl{'fetch'} = 0;
			$use{'downloader'} = 1;}
		elsif ($arg == 43){
			$dl{'wget'} = 0;
			$use{'downloader'} = 1;}
		elsif ($arg == 44){
			$dl{'curl'} = 0;
			$dl{'fetch'} = 0;
			$dl{'wget'} = 0;
			$use{'downloader'} = 1;}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	# set --arm flag separately since android can be on different platforms
	'android' => sub {
		$b_android = 1;},
	'arm' => sub {
		undef %risc;
		$risc{'id'} = 'arm';
		$risc{'arm'} = 1;},
	'bsd:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg =~ /^(darwin|dragonfly|freebsd|openbsd|netbsd)$/i){
			$bsd_type = lc($arg);
			$fake{'bsd'} = 1;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}
	},
	'bt-tool:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg =~ /^(bluetoothctl|bt-adapter|btmgmt|hciconfig|rfkill)$/i){
			$force{lc($arg)} = 1;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}
	},
	'cygwin' => sub {
		$windows{'cygwin'} = 1;},
	'dbg:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg !~ /^\d+(,\d+)*$/){
			main::error_handler('bad-arg', $opt, $arg);
		}
		for (split(',',$arg)){
			$dbg[$_] = 1;
		}},
	'debug:i' => sub { 
		my ($opt,$arg) = @_;
		if ($arg =~ /^[1-3]|1[0-3]|2[0-4]$/){
			$debugger{'level'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'debug-arg:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg && $arg =~ /^--?[a-z]/ig){
			$debugger{'arg'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'debug-arg-use:s' => sub { 
		my ($opt,$arg) = @_;
		print "$arg\n";
		if ($arg && $arg =~ /^--?[a-z]/ig){
			$debugger{'arg-use'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'debug-filter|debug-z' => sub {
		$debugger{'filter'} = 1 },
	'debug-id:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg){
			$debugger{'id'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'debug-no-eps' => sub {
		$debugger{'no-exit'} = 1;
		$debugger{'no-proc'} = 1;
		$debugger{'sys'} = 0;
	},
	'debug-no-exit' => sub {
		$debugger{'no-exit'} = 1 },
	'debug-no-proc' => sub {
		$debugger{'no-proc'} = 1;},
	'debug-no-sys' => sub {
		$debugger{'sys'} = 0;},
	'debug-proc' => sub {
		$debugger{'proc'} = 1;},
	'debug-proc-print' => sub {
		$debugger{'proc-print'} = 1;},
	'debug-sys-print' => sub {
		$debugger{'sys-print'} = 1;},
	'debug-test-1' => sub {
		$debugger{'test-1'} = 1;},
	'debug-width|debug-y:i' => sub { 
		my ($opt,$arg) = @_;
		$arg ||= 80;
		if ($arg =~ /^\d+$/ && ($arg == 1 || $arg >= 80)){
			$debugger{'width'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'debug-zy|debug-yz:i' => sub { 
		my ($opt,$arg) = @_;
		$arg ||= 80;
		if ($arg =~ /^\d+$/ && ($arg == 1 || $arg >= 80)){
			$debugger{'width'} = $arg;
			$debugger{'filter'} = 1;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'dig' => sub {
		$force{'no-dig'} = 0;},
	'display:s' => sub { 
		my ($opt,$arg) = @_;
		if ($arg =~ /^:?([0-9\.]+)?$/){
			$display=$arg;
			$display ||= ':0';
			$display = ":$display" if $display !~ /^:/;
			$b_display = ($b_root) ? 0 : 1;
			$force{'display'} = 1;
			$display_opt = "-display $display";
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'dmi|dmidecode' => sub {
		$force{'dmidecode'} = 1;},
	'downloader:s' => sub { 
		my ($opt,$arg) = @_;
		$arg = lc($arg);
		if ($arg =~ /^(curl|fetch|ftp|perl|wget)$/){
			if ($arg eq 'perl' && (!main::check_perl_module('HTTP::Tiny') || 
			 !main::check_perl_module('IO::Socket::SSL'))){
				main::error_handler('missing-perl-downloader', $opt, $arg);
			}
			elsif (!main::check_program($arg)){
				main::error_handler('missing-downloader', $opt, $arg);
			}
			else {
				# this dumps all the other data and resets %dl for only the
				# desired downloader.
				$arg = main::set_perl_downloader($arg);
				%dl = ('dl' => $arg, $arg => 1);
				$use{'downloader'} = 1;
			}
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'fake:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			my $wl = 'bluetooth|compiler|cpu|dboot|dmidecode|egl|elbrus|glx|';
			$wl .= 'iomem|ip-if|ipmi|logical|lspci|partitions|pciconf|pcictl|pcidump|';
			$wl .= 'raid-btrfs|raid-hw|raid-lvm|raid-md|raid-soft|raid-zfs|';
			$wl .= 'sensors|sensors-sys|swaymsg|sys-mem|sysctl|';
			$wl .= 'udevadm|uptime|usbconfig|usbdevs|vmstat|vulkan|wl-info|wlr-randr|';
			$wl .= 'xdpyinfo|xorg-log|xrandr';
			for (split(',',$arg)){
				if ($_ =~ /\b($wl)\b/){
					$fake{lc($1)} = 1;
				}
				else {
					main::error_handler('bad-arg', $opt, $_);
				}
			}
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'fake-data-dir:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg && -d $arg){
			$fake_data_dir = $arg;
		}
		else {
			main::error_handler('dir-not-exist', $opt, $arg);
		}},
	'force:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			my $wl = 'bluetoothctl|bt-adapter|btmgmt|colors|cpuinfo|display|dmidecode|';
			$wl .= 'hciconfig|hddtemp|ip|ifconfig|lsusb|man|meminfo|';
			$wl .= 'no-dig|no-doas|no-html-wan|no-sudo|pkg|rfkill|rpm|sensors-sys|';
			$wl .= 'udevadm|usb-sys|vmstat|wayland|wmctrl';
			for (split(',',$arg)){
				if ($_ =~ /\b($wl)\b/){
					$force{lc($1)} = 1;
				}
				else {
					main::error_handler('bad-arg', $opt, $_);
				}
			}
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'ftp:s'  => sub { 
		my ($opt,$arg) = @_;
		# pattern: ftp.x.x/x
		if ($arg =~ /^ftp\..+\..+\/[^\/]+$/){
			$ftp_alt = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'hddtemp' => sub {
		$force{'hddtemp'} = 1;},
	'host|hostname' => sub {
		$show{'host'} = 1;
		$show{'no-host'} = 0;},
	'html-wan' => sub {
		$force{'no-html-wan'} = 0;},
	'ifconfig' => sub {
		$force{'ifconfig'} = 1;},
	'indent:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg >= 11){
			$size{'indent'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'indents:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg >= 0 && $arg < 11){
			$size{'indents'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'irc' => sub {
		$b_irc = 1;},
	'man' => sub {
		$use{'yes-man'} = 1;},
	'max-wrap|wrap-max|indent-min:i' => sub {
		my ($opt,$arg) = @_;
		if ($arg >= 0){
			$size{'max-wrap'} = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'mips' => sub {
		undef %risc;
		$risc{'id'} = 'mips';
		$risc{'mips'} = 1;},
	'no-dig' => sub {
		$force{'no-dig'} = 1;},
	'no-doas' => sub {
		$force{'no-doas'} = 1;},
	'no-host|no-hostname' => sub {
		$show{'host'} = 0;
		$show{'no-host'} = 1;},
	'no-html-wan' => sub {
		$force{'no-html-wan'}= 1;},
	'no-man' => sub {
		$use{'no-man'} = 0;},
	'no-ssl' => sub {
		$use{'no-ssl'} = 1;},
	'no-sudo' => sub {
		$force{'no-sudo'} = 1;},
	'output|export:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg =~ /^(json|screen|xml)$/){
			$output_type = $arg;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'output-file|export-file:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg){
			if ($arg eq 'print' || main::check_output_path($arg)){
				$output_file = $arg;
			}
			else {
				main::error_handler('output-file-bad', $opt, $arg);
			}
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'pkg|rpm' => sub {
		$force{'pkg'} = 1;},
	'ppc' => sub {
		undef %risc;
		$risc{'id'} = 'ppc';
		$risc{'ppc'} = 1;},
	'recommends' => sub {
		$show{'recommends'} = 1;},
	'riscv' => sub {
		undef %risc;
		$risc{'id'} = 'riscv';
		$risc{'riscv'} = 1;},
	'sensors-sys' => sub {
		$force{'sensors-sys'} = 1;},
	'sparc' => sub {
		undef %risc;
		$risc{'id'} = 'sparc';
		$risc{'sparc'} = 1;},
	'sys-debug' => sub {
		$debugger{'sys-force'} = 1;},
	'tty' => sub { # workaround for ansible/scripts running this
		$b_irc = 0;},
	'U|update:s' => sub { # 1,2,3,4 OR http://myserver/path/inxi
		my ($opt,$arg) = @_;
		process_updater($opt,$arg);},
	'usb-sys' => sub {
		$force{'usb-sys'} = 1;},
	'usb-tool' => sub {
		$force{'lsusb'} = 1;},
	'wan-ip-url:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg && $arg =~ /^(f|ht)tp[s]?:\/\//){
			$wan_url = $arg;
			$force{'no-dig'} = 1;
		}
		else {
			main::error_handler('bad-arg', $opt, $arg);
		}},
	'wayland|wl' => sub { 
		$force{'wayland'} = 1;},
	'wm|wmctrl' => sub { 
		$force{'wmctrl'} = 1;},
	'wsl' => sub {
		$windows{'wsl'} = 1;},
	'<>' => sub {
		my ($opt) = @_;
		main::error_handler('unknown-option', "$opt", "");}
	); # or error_handler('unknown-option', "@ARGV", '');
	# run all these after so that we can change widths, downloaders, etc
	post_process();
	eval $end if $b_log;
}

# These options require other option[s] to function, and have no meaning alone.
sub check_modifiers {
	if ($use{'cpu-sleep'} && !$show{'cpu'} && !$show{'cpu-basic'} && 
	!$show{'short'}){
		main::error_handler('arg-modifier', '--sleep', '[no-options], -b, -C, -v [>0]');
	}
	if ($show{'label'} && !$show{'partition'} && !$show{'partition-full'} && 
	!$show{'swap'} && !$show{'unmounted'}){
		main::error_handler('arg-modifier', '-l/--label', '-j, -o, -p, -P');
	}
	if ($use{'ip-limit'} && !$show{'ip'}){
		main::error_handler('arg-modifier', '--limit', '-i');
	}
	if ($output_type && $output_type ne 'screen' && !$output_file){
		main::error_handler('arg-modifier', '--output', '--output-file [filename]');
	}
	if ($use{'partition-sort'} && !$show{'partition'} && !$show{'partition-full'}){
		main::error_handler('arg-modifier', '--partition-sort', '-p, -P');
	}
	if ($use{'sensors-default'} && !$show{'sensor'}){
		main::error_handler('arg-modifier', '--sensors-default', '-s');
	}
	if ($use{'sensors-exclude'} && !$show{'sensor'}){
		main::error_handler('arg-modifier', '--sensors-exclude', '-s');
	}
	if ($use{'sensors-use'} && !$show{'sensor'}){
		main::error_handler('arg-modifier', '--sensors-use', '-s');
	}
	if ($show{'uuid'} && !$show{'machine'} && !$show{'partition'} && 
	!$show{'partition-full'} && !$show{'swap'} && !$show{'unmounted'}){
		main::error_handler('arg-modifier', '-u/--uuid', '-j, -M, -o, -p, -P');
	}
	if ($use{'weather-source'} && !$show{'weather'}){
		main::error_handler('arg-modifier', '--weather-source/--ws', '-w');
	}
	if ($use{'weather-unit'} && !$show{'weather'}){
		main::error_handler('arg-modifier', '--weather-unit/--wu', '-w');
	}
}

sub post_process {
	# first run all the stuff that exits after running
	CheckRecommends::run() if $show{'recommends'};
	Configs::show() if $show{'configs'};
	main::show_options() if $show{'help'};
	main::show_version() if ($show{'version'} || $show{'version-short'});
	# sets for either config or arg here
	if ($use{'downloader'} || $wan_url || ($force{'no-dig'} && $show{'ip'})){
		main::set_downloader();
	}
	$use{'man'} = 0 if (!$use{'yes-man'} || $use{'no-man'});
	main::update_me($self_download,$download_id) if $use{'update-trigger'};
	main::set_xorg_log() if $show{'graphic'};
	set_pledge() if $b_pledge;
	$extra = 3 if $b_admin; # before check_modifiers in case we make $estra based.
	check_modifiers();
	# this turns off basic for F/v graphic output levels. 
	if ($show{'graphic-basic'} && $show{'graphic-full'} && $extra > 1){
		$show{'graphic-basic'} = 0;
	}
	if ($force{'rpm'}){
		$force{'pkg'} = 1;
		delete $force{'rpm'};
	}
	if ($use{'sensors-default'}){
		@sensors_exclude = ();
		@sensors_use = ();
	}
	if ($show{'short'} || $show{'disk'} || $show{'disk-basic'} || $show{'disk-total'} || 
	$show{'logical'} || $show{'partition'} || $show{'partition-full'} || $show{'raid'} || 
	$show{'unmounted'}){
		$use{'block-tool'} = 1;
	}
	if ($show{'short'} || $show{'raid'} || $show{'disk'} || $show{'disk-total'} || 
	$show{'disk-basic'} || $show{'unmounted'}){
		$use{'btrfs'} = 1;
		$use{'mdadm'} = 1;
	}
	if ($b_admin && $show{'disk'}){
		$use{'smartctl'} = 1;
	}
	# triggers may extend to -D, -pP
	if ($show{'short'} || $show{'logical'} || $show{'raid'} || $show{'disk'} || 
	$show{'disk-total'} || $show{'disk-basic'} || $show{'unmounted'}){
		$use{'logical'} = 1;
	}
	main::set_sudo() if ($show{'unmounted'} || ($extra > 0 && $show{'disk'}));
	if ($use{'filter-override'}){
		$use{'filter'} = 0;
		$use{'filter-label'} = 0;
		$use{'filter-uuid'} = 0;
		$use{'filter-vulnerabilities'} = 0;
	}
	# override for things like -b or -v2 to -v3
	$show{'cpu-basic'} = 0 if $show{'cpu'};
	$show{'optical-basic'} = 0 if $show{'optical'};
	$show{'partition'} = 0 if $show{'partition-full'};
	$show{'host'} = 0 if $show{'no-host'};
	$show{'host'} = 1 if ($show{'host'} || (!$use{'filter'} && !$show{'no-host'}));
	if ($show{'disk'} || $show{'optical'}){
		$show{'disk-basic'} = 0;
		$show{'disk-total'} = 0;
	}
	if ($show{'ram'} || $show{'slot'} || 
	($show{'cpu'} && ($extra > 1 || $bsd_type)) || 
	(($bsd_type || $force{'dmidecode'}) && ($show{'machine'} || $show{'battery'}))){
		$use{'dmidecode'} = 1;
	}
	if (!$bsd_type && ($show{'ram'})){
		$use{'udevadm'} = 1;
	}
	if ($show{'audio'} || $show{'bluetooth'} || $show{'graphic'} || 
	$show{'network'} || $show{'raid'}){
		$use{'pci'} = 1;
	}
	if ($show{'usb'} || $show{'audio'} || $show{'bluetooth'} || $show{'disk'} || 
	$show{'graphic'} || $show{'network'}){
		$use{'usb'} = 1;
	}
	if ($bsd_type){
		if ($show{'audio'}){
			$use{'bsd-audio'} = 1;}
		if ($show{'battery'}){
			$use{'bsd-battery'} = 1;}
		if ($show{'short'} || $show{'cpu-basic'} || $show{'cpu'}){
			$use{'bsd-cpu'} = 1;
			$use{'bsd-sleep'} = 1;}
		if ($show{'short'} || $show{'disk-basic'} || $show{'disk-total'} || 
		$show{'disk'} || $show{'partition'} || $show{'partition-full'} || 
		$show{'raid'} || $show{'swap'} || $show{'unmounted'}){
			$use{'bsd-disk'} = 1;
			$use{'bsd-partition'} = 1;
			$use{'bsd-raid'} = 1;}
		if ($show{'system'}){
			$use{'bsd-kernel'} = 1;}
		if ($show{'machine'}){
			$use{'bsd-machine'} = 1;}
		if ($show{'short'} || $show{'info'} || $show{'ps-mem'} || $show{'ram'}){
			$use{'bsd-memory'} = 1;}
		if ($show{'optical-basic'} || $show{'optical'}){
			$use{'bsd-optical'} = 1;}
		# strictly only used to fill in pci drivers if tool doesn't support that
		if ($use{'pci'}){
			$use{'bsd-pci'} = 1;}
		if ($show{'raid'}){
			$use{'bsd-raid'} = 1;}
		if ($show{'ram'}){
			$use{'bsd-ram'} = 1;}
		if ($show{'sensor'}){
			$use{'bsd-sensor'} = 1;}
		# always use this, it's too core
		$use{'sysctl'} = 1;
	}
}

sub process_updater {
	my ($opt,$arg) = @_;
	$use{'downloader'} = 1;
	if ($use{'update'}){
		$use{'update-trigger'} = 1;
		if (!$arg){
			$use{'man'} = 1;
			$download_id = "$self_name main branch";
			$self_download = main::get_defaults("$self_name-main");
		}
		elsif ($arg && $arg eq '3'){
			$use{'man'} = 1;
			$download_id = 'dev server';
			$self_download = main::get_defaults("$self_name-dev");
		}
		elsif ($arg && $arg eq '4'){
			$use{'man'} = 1;
			$use{'ftp-download'} = 1;
			$download_id = 'dev server ftp';
			$self_download = main::get_defaults("$self_name-dev-ftp");
		}
		elsif ($arg =~ /^[12]$/){
			if ($self_name eq 'inxi'){
				$download_id = "branch $arg";
				$self_download = main::get_defaults("inxi-branch-$arg");
			}
			else {
				main::error_handler('bad-arg', $opt, $arg);
			}
		}
		elsif ($arg =~ /^(ftp|https?):/){
			$download_id = 'alt server';
			$self_download = $arg;
		}
		if ($self_download && $self_name eq 'inxi'){
			$use{'man'} = 1;
			$use{'yes-man'} = 1;
		}
		if (!$self_download){
			main::error_handler('bad-arg', $opt, $arg);
		}
	}
	else {
		main::error_handler('distro-block', $opt);
	} 
}

sub set_pledge {
	my $b_update;
	# if -c 9x, remove in SelectColors::set_selection(), else remove here
	if (!$colors{'selector'} && $debugger{'level'} < 21){
		@pledges = grep {$_ ne 'getpw'} @pledges; 
		$b_update = 1;
	}
	if ($debugger{'level'} < 21){ # remove ftp upload
		@pledges = grep {!/(dns|inet)/} @pledges;
		$b_update = 1;
	}
	# not writing/creating .inxi data dirs colors selector launches set_color()
	if (!$show{'weather'} && !$colors{'selector'} && $debugger{'level'} < 10 && 
		$output_type eq 'screen'){ 
		@pledges = grep {!/(cpath|wpath)/} @pledges;
		$b_update = 1;
	}
	OpenBSD::Pledge::pledge(@pledges) if $b_update;
}
}

sub show_options {
	error_handler('not-in-irc', 'help') if $b_irc;
	my $rows = [];
	my $line = make_line();
	my $color_scheme_count = get_color_scheme('count') - 1; 
	my $partition_string='partition';
	my $partition_string_u='Partition';
	my $flags = (%risc || $bsd_type) ? 'features' : 'flags' ;
	if ($bsd_type){
		$partition_string='slice';
		$partition_string_u='Slice';
	}
	# fit the line to the screen!
	push(@$rows, 
	['0', '', '', "$self_name supports the following options. For more detailed 
	information, see man^$self_name. If you start $self_name with no arguments,
	it will display a short system summary."],
	['0', '', '', ''],
	['0', '', '', "You can use these options alone or together, 
	to show or add the item(s) you want to see: A, B, C, d, D, E, f, G, i, I, j, 
	J, l, L, m, M, n, N, o, p, P, r, R, s, S, t, u, w, --edid, --mm, --ms, 
	--slots. If you use them with -v [level], -b or -F, $self_name will add the
	requested lines to the output."],
	['0', '', '', '' ],
	['0', '', '', "Examples:^$self_name^-v4^-c6 OR $self_name^-bDc^6 OR
	$self_name^-FzjJxy^80"],
	['0', '', '', $line ],
	['0', '', '', "See Filter Options for output filtering, Output Control Options
	for colors, sizing, output changes, Extra Data Options to extend Main output,
	Additional Options and Advanced Options for less common situations."],
	['0', '', '', $line ],
	['0', '', '', "Main Feature Options:"],
	['1', '-A', '--audio', "Audio/sound devices(s), driver; active sound APIs and 
	servers."],
	['1', '-b', '--basic', "Basic output, short form. Same as $self_name^-v^2."],
	['1', '-B', '--battery', "System battery info, including charge, condition
	voltage (if critical), plus extra info (if battery present/detected)."],
	['1', '-C', '--cpu', "CPU output (if each item available): basic topology,
	model, type (see man for types), cache, average CPU speed, min/max speeds, 
	per core clock speeds."],
	['1', '-d', '--disk-full, --optical', "Optical drive data (and floppy disks, 
	if present). Triggers -D."],
	['1', '-D', '--disk', "Hard Disk info, including total storage and details 
	for each disk. Disk total used percentage includes swap ${partition_string}
	size(s)."],
	['1', '-E', '--bluetooth', "Show bluetooth device data and report, if 
	available. Shows state, address, IDs, version info."],
	['1', '', '--edid', "Full graphics data, triggers -a, -G. Add monitor chroma,
	full modelines (if > 2), EDID errors and warnings, if present."],
	['1', '-f', '--flags', "All CPU $flags. Triggers -C. Not shown with -F to 
	avoid spamming."],
	['1', '-F', '--full', "Full output. Includes all Upper Case line letters 
	(except -J, -W) plus --swap, -s and -n. Does not show extra verbose options 
	such as -d -f -i -J -l -m -o -p -r -t -u -x, unless specified."],
	['1', '-G', '--graphics', "Graphics info (devices(s), drivers, display 
	protocol (if available), display server/Wayland compositor, resolution, X.org: 
	renderer, basic EGL, OpenGL, Vulkan API data; Xvesa API: VBE info."],
	['1', '-i', '--ip', "WAN IP address and local interfaces (requires ifconfig 
	or ip network tool). Triggers -n. Not shown with -F for user security reasons. 
	You shouldn't paste your local/WAN IP."],
	['1', '', '--ip-limit, --limit', "[-1; 1-x] Set max output limit of IP 
	addresses for -i (default 10; -1 removes limit)."],
	['1', '-I', '--info', "General info, including processes, uptime, memory (if 
	-m/-tm not used), IRC client or shell type, $self_name version."],
	['1', '-j', '--swap', "Swap in use. Includes ${partition_string}s, zram, 
	file."],
	['1', '-J', '--usb', "Show USB data: Hubs and Devices."],
	['1', '-l', '--label', "$partition_string_u labels. Use with -j, -o, -p, -P."],
	['1', '-L', '--logical', "Logical devices, LVM (VG, LV), 
	LUKS, Crypto, bcache, etc. Shows components/devices, sizes, etc."],
	['1', '-m', '--memory', "Memory (RAM) data. Numbers of devices (slots) 
	supported and individual memory devices (sticks of memory etc). For devices, 
	shows device locator, type (e.g. DDR3), size, speed. Also shows System RAM 
	report, and removes Memory report from -I or -tm."],
	['1', '', '--memory-modules,--mm', "Memory (RAM) data. Exclude empty module slots."],
	['1', '', '--memory-short,--ms', "Memory (RAM) data. Show only short Memory RAM 
	report, number of arrays, slots, modules, and RAM type."],
	['1', '-M', '--machine', "Machine data. Device type (desktop, server, laptop, 
	VM etc.), motherboard, BIOS and, if present, system builder (e.g. Lenovo). 
	Shows UEFI/BIOS/UEFI [Legacy]. Older systems/kernels without the required /sys 
	data can use dmidecode instead, run as root. Dmidecode can be forced with 
	--dmidecode"],
	['1', '-n', '--network-advanced', "Advanced Network device info. Triggers -N. 
	Shows interface, speed, MAC id, state, etc. "],
	['1', '-N', '--network', "Network device(s), driver."],
	['1', '-o', '--unmounted', "Unmounted $partition_string info (includes UUID 
	and Label if available). Shows file system type if you have lsblk installed 
	(Linux) or, for BSD/GNU Linux, if 'file' installed and you are root or if 
	you have added to /etc/sudoers (sudo v. 1.7 or newer)(or try doas)."],
	['1', '', '', "Example: ^<username>^ALL^=^NOPASSWD:^/usr/bin/file^"],
	['1', '-p', '--partitions-full', "Full $partition_string information (-P plus 
	all other detected ${partition_string}s)."],
	['1', '', '--partitions-sort, --ps', "
	[dev-base|fs|id|label|percent-used|size|uuid|used] Change sort order of 
	${partition_string} output. See man page for specifics."],
	['1', '-P', '--partitions', "Basic $partition_string info. Shows, if detected: 
	/ /boot /home /opt /tmp /usr /usr/home /var /var/log /var/tmp. Swap 
	${partition_string}s show if --swap is not used. Use -p to see all 
	mounted ${partition_string}s."],
	['1', '-r', '--repos', "Distro repository data. Supported repo types: APK, 
	APT, CARDS, EOPKG, NETPKG, NIX, PACMAN, PACMAN-G2, PISI, PKG (BSDs), PORTAGE, 
	PORTS (BSDs), SBOPKG, SBOUI, SCRATCHPKG, SLACKPKG, SLAPT_GET, SLPKG, TCE, 
	TAZPKG, URPMQ, XBPS, YUM/ZYPP."],
	['1', '-R', '--raid', "RAID data. Shows RAID devices, states, levels, array 
	sizes, and components. md-raid: If device is resyncing, also shows resync
	progress line."],
	['1', '-s', '--sensors', "Sensors output (if sensors installed/configured): 
	mobo/CPU/GPU temp; detected fan speeds. Nvidia shows screen number for > 1 
	screen. IPMI sensors if present."],
	['1', '', '--slots', "PCI slots: type, speed, status. Requires root."],
	['1', '-S', '--system', "System info: host name, kernel, desktop environment 
	(if in X/Wayland), distro."],
	['1', '-t', '--processes', "Processes. Requires extra options: c (CPU), m 
	(memory), cm (CPU+memory). If followed by numbers 1-x, shows that number 
	of processes for each type (default: 5; if in IRC, max: 5). "],
	['1', '', '', "Make sure that there is no space between letters and 
	numbers (e.g.^-t^cm10)."],
	['1', '-u', '--uuid', "$partition_string_u, system board UUIDs. Use with -j, 
	-M, -o, -p, -P."],
	['1', '-v', '--verbosity', "Set $self_name verbosity level (0-8). 
	Should not be used with -b or -F. Example: $self_name^-v^4"],
	['2', '0', '', "Same as: $self_name"],
	['2', '1', '', "Basic verbose, -S + basic CPU + -G + basic Disk + -I."],
	['2', '2', '', "Networking device (-N), Machine (-M), Battery (-B; if 
	present), and, if present, basic RAID (devices only; notes if inactive). Same 
	as $self_name^-b"],
	['2', '3', '', "Advanced CPU (-C), battery (-B), network (-n); 
	triggers -x. "],
	['2', '4', '', "$partition_string_u size/used data (-P) for 
	(if present) /, /home, /var/, /boot. Shows full disk data (-D). "],
	['2', '5', '', "Audio device (-A), sensors (-s), memory/RAM (-m), 
	bluetooth (if present), $partition_string label^(-l), full swap (-j), 
	UUID^(-u), short form of optical drives, RAID data (if present)."],
	['2', '6', '', "Full $partition_string (-p), 
	unmounted $partition_string (-o), optical drive (-d), USB (-J),
	full RAID; triggers -xx."], 
	['2', '7', '', "Network IP data (-i), bluetooth, logical (-L), 
	RAID forced, full CPU $flags; triggers -xxx."],
	['2', '8', '', "Everything available, including	advanced gpu EDID (--edid)
	data, repos (-r), processes (-tcm), PCI slots (--slots); triggers 
	admin (-a)."],
	);
	# if distro maintainers don't want the weather feature disable it
	if ($use{'weather'}){
		push(@$rows, 
		['1', '-w', '--weather', "NO^AUTOMATED^QUERIES^OR^EXCESSIVE^USE^ALLOWED!"],
		['1', '', '', "Without [location]: Your current local (local to 
		your IP address) weather data/time.Example:^$self_name^-w"],
		['1', '', '', "With [location]: Supported location options are: 
		postal code[,country/country code]; city, state (USA)/country 
		(country/two character country code); latitude, longitude. Only use if you 
		want the weather somewhere other than the machine running $self_name. Use 
		only ASCII characters, replace spaces in city/state/country names with '+'. 
		Example:^$self_name^-w^[new+york,ny^london,gb^madrid,es]"],
		['1', '', '--weather-source,--ws', "[1-9] Change weather data source. 1-4 
		generally active, 5-9 check. See man."],
		['1', '', '--weather-unit,--wu', "Set weather units to metric (m), imperial 
		(i), metric/imperial (mi), or imperial/metric (im)."],
		);
	}
	push(@$rows, 
	[0, '', '', "$line"],
	['0', '', '', "Filter Options:"],
	['1', '', '--host', "Turn on hostname for -S. Overrides -z."],
	['1', '', '--no-host', "Turn off hostname for -S. Useful if showing output 
	from servers etc. Activated by -z as well."],
	['1', '-z', '--filter', "Adds security filters for IP/MAC addresses, serial 
	numbers, location (-w), user home directory name, host name. Default on for 
	IRC clients."],
	['1', '', '--za,--filter-all', "Shortcut, triggers -z, --zl, --zu, --zv."],
	['1', '', '--zl,--filter-label', "Filters out ${partition_string} labels in 
	-j, -o, -p, -P, -Sa."],
	['1', '', '--zu,--filter-uuid', "Filters out ${partition_string} UUIDs in -j, 
	-o, -p, -P, -Sa, board UUIDs in -Mxxx."],
	['1', '', '--zv,--filter-vulnerabilities', "Filters out Vulnerabilities 
	report in -Ca."],
	['1', '-Z', '--no-filter', "Disable output filters. Useful for 	debugging 
	networking issues in IRC, or you needed to use --tty, for example."],
	[0, '', '', "$line"],
	['0', '', '', "Output Control Options:"],
	['1', '-c', '--color', "Set color scheme (0-42). For piped or redirected 
	output, you must use an explicit color selector. Example:^$self_name^-c^11"],
	['1', '', '', "Color selectors let you set the config file value for the 
	selection (NOTE: IRC and global only show safe color set)"],
	['2', '94', '', "Console, out of X"],
	['2', '95', '', "Terminal, running in X - like xTerm"],
	['2', '96', '', "Gui IRC, running in X - like Xchat, Quassel, Konversation 
	etc."],
	['2', '97', '', "Console IRC running in X - like irssi in xTerm"],
	['2', '98', '', "Console IRC not in  X"],
	['2', '99', '', "Global - Overrides/removes all settings. Setting specific 
	removes global."],
	['1', '', '--indent', "[11-20] Change default wide mode primary indentation 
	width."],
	['1', '', '--indents', "[0-10] Change wrapped mode primary indentation width,
	and secondary / -y1 indent widths."],
	['1', '', '--max-wrap,--wrap-max', "[70-xxx] Set maximum width where 
	$self_name autowraps line starters. Current: $size{'max-wrap'}"],
	['1', '', '--output', "[json|screen|xml] Change data output type. Requires 
	--output-file if not screen."],
	['1', '', '--output-file', "[Full filepath|print] Output file to be used for 
	--output."],
	['1', '', '--separator, --sep', "[key:value separator character]. Change 
	separator character(s) for key: value pairs."],
	['1', '-y', '--width', "[empty|-1|1|60-xxx] Output line width max. Overrides 
	IRC/Terminal settings or actual widths. If no integer give, defaults to 80. 
	-1 removes line lengths. 1 switches output to 1 key/value pair per line. 
	Example:^inxi^-y^130"],
	['1', '-Y', '--height', "[empty|-3-xxx] Output height control. Similar to 
	'less' command except colors preserved, defaults to console/terminal height. 
	-1 shows 1 primary Item: at a time; -2 retains color on redirect/piping (to 
	less -R); -3 removes configuration value; 0 or -Y sets to detected terminal 
	height. Greater than 0 shows x lines at a time."],
	['0', '', '', "$line"],
	['0', '', '', "Extra Data Options:"],
	['1', '-x', '--extra', "Adds the following extra data (only works with 
	verbose or line output, not short form):"],
	['2', '-A', '', "Specific vendor/product information (if relevant); 
	PCI/USB ID of device; Version/port(s)/driver version (if available);
	inactive sound servers/APIs."],
	['2', '-B', '', "Current/minimum voltage, vendor/model, status (if available); 
	attached devices (e.g. wireless mouse, keyboard, if present)."],
	['2', '-C', '', "L1/L3 cache (if most Linux, or if root and dmidecode 
	installed); smt if disabled, CPU $flags (short list, use -f to see full list);
	Highest core speed (if > 1 core); CPU boost (turbo) enabled/disabled, if
	present; Bogomips on CPU; CPU microarchitecture + 	revision (if found, or 
	unless --admin, then shows as 'stepping')."],
	['2', '-d', '', "Extra optical drive features data; adds rev version to 
	optical drive."],
	['2', '-D', '', "HDD temp with disk data. Kernels >= 5.6: enable module
	drivetemp if not enabled. Older systems require hddtemp, run as
	as superuser, or as user if you have added hddtemp to /etc/sudoers
	(sudo v. 1.7 or newer)(or try doas). 
	Example:^<username>^ALL^=^NOPASSWD:^/usr/sbin/hddtemp"],
	['2', '-E', '', "PCI/USB Bus ID of device, driver version, 
	LMP version."],
	['2', '-G', '', "GPU arch (AMD/Intel/Nvidia only); Specific vendor/product 
	information (if relevant); PCI/USB ID of device; Screen number GPU is running 
	on (Nvidia only); device temp (Linux, if found); APIs: EGL: active/inactive 
	platforms; OpenGL: direct rendering status (in X); Vulkan device counts."],
	['2', '-i', '', "For IPv6, show additional scope addresses: Global, Site, 
	Temporary, Unknown. See --limit for large counts of IP addresses."],
	['2', '-I', '', "Default system compilers. With -xx, also shows other 
	installed compiler versions. If running in shell, not in IRC client, shows 
	shell version number, if detected. Init/RC type and runlevel/target (if 
	available). Total count of all packages discovered in system (if not -r)."],
	['2', '-j', '', "Add mapped: name if partition mapped."],
	['2', '-J', '', "For Device: driver; Si speed (base 10, bits/s)."],
	['2', '-L', '', "For VG > LV, and other Devices, dm:"],
	['2', '-m,--mm', '', "Max memory module size (if available)."],
	['2', '-N', '', "Specific vendor/product information (if relevant); 
	PCI/USB ID of device; Version/port(s)/driver version (if available); device
	temperature (Linux, if found)."],
	['2', '-o,-p,-P', '', "Add mapped: name if partition mapped."],
	['2', '-r', '', "Packages, see -Ix."],
	['2', '-R', '', "md-raid: second RAID Info line with extra data: 
	blocks, chunk size, bitmap (if present). Resync line, shows blocks 
	synced/total blocks. Hardware RAID driver version, bus-ID."],
	['2', '-s', '', "Basic voltages (ipmi, lm-sensors if present): 12v, 5v, 3.3v, 
	vbat."],
	['2', '-S', '', "Kernel gcc version; system base of distro (if relevant 
	and detected)"],
	['2', '', '--slots', "Adds BusID for slot."],
	['2', '-t', '', "Adds memory use output to CPU (-xt c), and CPU use to 
	memory (-xt m)."],
	);
	if ($use{'weather'}){
		push(@$rows, 
		['2', '-w', '', "Wind speed and direction, humidity, pressure, and time
		zone, if available."]);
	}
	push(@$rows, 
	['0', '', '', ''],
	['1', '-xx', '--extra 2', "Show extra, extra data (only works with verbose 
	or line output, not short form):"],
	['2', '-A', '', "Chip vendor:product ID for each audio device; PCIe speed,
	lanes (if found); USB rev, speed, lanes (if found); sound server/api helper 
	daemons/plugins."],
	['2', '-B', '', "Power used, in watts; serial number."],
	['2', '-D', '', "Disk transfer speed; NVMe lanes; USB rev, speed, lanes (if 
	found); Disk serial number; LVM volume group free space (if available); disk 
	duid (some BSDs)."],
	['2', '-E', '', "Chip vendor:product ID, LMP subversion; PCIe speed, lanes 
	(if found); USB rev, speed, lanes (if found)."],
	['2', '-G', '', "Chip vendor:product ID for each video device; Output ports, 
	used and empty; PCIe speed, lanes (if found); USB rev, speed, lanes (if 
	found); Xorg: Xorg compositor; alternate Xorg drivers (if available. Alternate 
	means driver is on automatic driver check list of Xorg for the device vendor, 
	but is not installed on system); Xorg Screen data: ID, s-res, dpi;  Monitors: 
	ID, position (if > 1), resolution, dpi, model, diagonal; APIs: EGL: per 
	platform report; OpenGL: ES version, device-ID, display-ID (if not found in 
	Display line); Vulkan: per device report."], 
	['2', '-I', '', "Adds Power: with children uptime, wakeups (from suspend); 
	other detected installed gcc versions (if present). System default 
	target/runlevel. Adds parent program (or pty/tty) for shell info if not in 
	IRC. Adds Init version number, RC (if found). Adds per package manager 
	installed package counts (if not -r)."],
	['2', '-j,-p,-P', '', "Swap priority."],
	['2', '-J', '', "Vendor:chip-ID; lanes (Linux only)."],
	['2', '-L', '', "Show internal LVM volumes, like raid image/meta volumes;
	for LVM RAID, adds RAID report line (if not -R); show all components >
	devices, number of 'c' or 'p' indicate depth of device."],
	['2', '-m,--mm', '', "Manufacturer, part number; single/double 
	bank (if found); memory array voltage (legacy, rare); module voltage (if 
	available)."],
	['2', '-M', '', "Chassis info, part number, BIOS ROM size (dmidecode only), 
	if available."],
	['2', '-N', '', "Chip vendor:product ID; PCIe speed, lanes (if found); USB 
	rev, speed, lanes (if found)."],
	['2', '-r', '', "Packages, see -Ixx."],
	['2', '-R', '', "md-raid: Superblock (if present), algorithm. If resync, 
	shows progress bar. Hardware RAID Chip vendor:product ID."],
	['2', '-s', '', "DIMM/SOC voltages (ipmi only)."],
	['2', '-S', '', "Desktop toolkit (tk), if available (only some DE/wm 
	supported); window manager (wm); display/Login manager (dm,lm) (e.g. kdm, 
	gdm3, lightdm, greetd, seatd)."],
	['2', '--slots', '', "Slot length; slot voltage, if available."],
	);
	if ($use{'weather'}){
		push(@$rows,
		['2', '-w', '', "Snow, rain, precipitation, (last observed hour), cloud 
		cover, wind chill, dew point, heat index, if available."]
		);
	}
	push(@$rows, 
	['0', '', '', ''],
	['1', '-xxx', '--extra 3', "Show extra, extra, extra data (only works 
	with verbose or line output, not short form):"],
	['2', '-A', '', "Serial number, class ID."],
	['2', '-B', '', "Chemistry, cycles, location (if available)."],
	['2', '-C', '', "CPU voltage, external clock speed (if root and dmidecode
	installed); smt status, if available."],
	['2', '-D', '', "Firmware rev. if available; partition scheme, in some cases; 
	disk type, rotation rpm (if available)."],
	['2', '-E', '', "Serial number, class ID, bluetooth device class ID, HCI 
	version and revision."],
	['2', '-G', '', "Device serial number, class ID; Xorg Screen size, diag; 
	Monitors: hz, size, modes, serial, scale, modes (max/min); APIs: EGL: hardware 
	driver info; Vulkan: layer count, device hardware vendor."],
	['2', '-I', '', "For Power:, adds states, suspend/hibernate active type; 
	For 'Shell:' adds ([doas|su|sudo|login]) to shell name if present; adds 
	default shell+version if different; for 'running in:' adds (SSH) if SSH 
	session."],
	['2', '-J', '', "If present: Devices: serial number, interface count, max 
	power."],
	['2', '-m,--mm', '', "Width of memory bus, data and total (if 
	present and greater than data); Detail for Type, if present; module current,
	min, max voltages (if present and different from each other); serial number."],
	['2', '-M', '', "Board/Chassis UUID, if available."],
	['2', '-N', '', "Serial number, class ID."],
	['2', '-R', '', "zfs-raid: portion allocated (used) by RAID devices/arrays. 
	md-raid: system md-raid support types (kernel support, read ahead, RAID 
	events). Hardware RAID rev, ports, specific vendor/product information."],
	['2', '-S', '', "Kernel clocksource; if in non console wm/desktop; window 
	manager version number; if available: panel/tray/bar/dock (with:); 
	screensavers/lockers running (tools:); virtual terminal number; 
	display/login manager version number."],
	);
	if ($use{'weather'}){
		push(@$rows, 
		['2', '-w', '', "Location (uses -z/irc filter), weather observation time, 
		altitude, sunrise/sunset, if available."] 
		);
	}
	push(@$rows, 
	['0', '', '', ''],
	['1', '-a', '--admin', "Adds advanced sys admin data (only works with 
	verbose or line output, not short form); check man page for explanations!; 
	also sets --extra=3:"],
	['2', '-A', '', "If available: list of alternate kernel modules/drivers 
	for device(s); PCIe lanes-max: gen, speed, lanes (if relevant); USB mode (if 
	found); list of installed tools for servers."],
	['2', '-C', '', "If available:  microarchitecture level (64 bit AMD/Intel 
	only).CPU generation, process node, built years; CPU socket type, base/boost 
	speeds (dmidecode+root/sudo/doas required); Full topology line, with cores, 
	threads, threads per core, granular cache data, smt status; CPU 
	vulnerabilities (bugs); family, model-id, stepping - format: hex (decimal) 
	if greater than 9; microcode format: hex."],
	['2', '-d,-D', '', "If available: logical and physical block sizes; drive 
	family; maj:min; USB mode (if found); USB drive specifics; SMART report."],
	['2', '-E', '', "PCIe lanes-max: gen, speed, lanes (if relevant); USB mode 
	(if found); If available: in Report:, adds status: discoverable, pairing; 
	adds Info: line: acl-mtu, sco-mtu, link-policy, link-mode, service-classes."],
	['2', '-G', '', "GPU process node, built year (AMD/Intel/Nvidia only); 
	non-free driver info (Nvidia only); PCIe lanes-max: gen, speed, lanes (if 
	relevant); USB mode (if found); list of alternate kernel modules/drivers for 
	device(s) (if available); Monitor built year, gamma, screen ratio (if 
	available); APIs: OpenGL: device memory, unified memory status; Vulkan: adds 
	full device report, device name, driver version, surfaces."],
	['2', '-I', '', "Adds to Power suspend/hibernate available non active states, 
	hibernate image size, suspend failed totals (if not 0), active power services; 
	Packages total number of lib files found for each package manager and pm tools 
	(if not -r); adds init service tool."],
	['2', '-j,-p,-P', '', "For swap (if available): swappiness and vfs cache 
	pressure, and if values are default or not."],
	['2', '-j', '', "Linux only: (if available): row one zswap data, and per zram
	row, active and available zram compressions, max compression streams."],
	['2', '-J', '', "Adds USB mode (Linux only); IEC speed (base 2, Bytes/s)."],
	['2', '-L', '', "LV, Crypto, devices, components: add maj:min; show
	full device/components report (speed, mapped names)."],
	['2', '-m', '', "Show full volts report, current, min, max, even if 
	identical; show firmware version (if available)."],
	['2', '-n,-i', '', "Info: services: line, with running network services."],
	['2', '-n,-N,-i', '', "If available: list of alternate kernel modules/drivers 
	for device(s); PCIe lanes-max: gen, speed, lanes (if relevant); USB mode (if 
	found)."],
	['2', '-o', '', "If available: maj:min of device."],
	['2', '-p,-P', '', "If available: raw size of ${partition_string}s, maj:min, 
	percent available for user, block size of file system (root required)."],
	['2', '-r', '', "Packages, see -Ia."],
	['2', '-R', '', "mdraid: device maj:min; per component: size, maj:min, state."],
	['2', '-S', '', "If available: kernel alternate clocksources, boot parameters;
	de extra data (info: eg kde frameworks); screensaver/locker tools available 
	but not active (avail:)."],
	['2', '--slots', '', "If available: slot bus ID children."],
	);
	push(@$rows, 
	[0, '', '', "$line"],
	[0, '', '', "Additional Options:"],
	['1', '--config', '--configuration', "Show active configurations, by file(s). 
	Last item listed overrides previous."],
	['1', '-h', '--help', "This help menu."],
 	['1', '', '--recommends', "Checks $self_name application dependencies + 
 	recommends, and directories, then shows what package(s) you need to install 
 	to add support for that feature."],
	);
	if ($use{'update'}){
		push(@$rows, 
		['1', '-U', '--update', "Auto-update $self_name. Will also install/update
		man page. Note: if you installed as root, you must be root to update, 
		otherwise user is fine. Man page installs require root. No arguments 
		downloads from main $self_name git repo."],
		['1', '', '', "Use alternate sources for updating $self_name"],
		['2', '3', '', "Get the dev server (smxi.org) version."],
		['2', '4', '', "Get the dev server (smxi.org) FTP version. Use if SSL issues
		and --no-ssl doesn't work."],
		['2', '[http|https|ftp]', '', "Get a version of $self_name from your own 
		server. Use the full download path, e.g.
		^$self_name^-U^https://myserver.com/inxi"],
		);
	}
	push(@$rows, 
	['1', '', '--version, --vf', "Prints full $self_name version info then exits."],
	['1', '', '--version-short,--vs', "Prints 1 line $self_name version info. Can 
	be used with other line options."],
	['0', '', '', "$line"],
	['0', '', '', "Advanced Options:"],
	['1', '', '--alt', "Trigger for various advanced options:"],
	['2', '40', '', "Bypass Perl as a downloader option."],
	['2', '41', '', "Bypass Curl as a downloader option."],
	['2', '42', '', "Bypass Fetch as a downloader option."],
	['2', '43', '', "Bypass Wget as a downloader option."],
	['2', '44', '', "Bypass Curl, Fetch, and Wget as downloader options. Forces 
	Perl if HTTP::Tiny present."],
	['1', '', '--bt-tool', "[bt-adapter btmgmt hciconfig rfkill] Force use of 
	given tool forbluetooth report. Or use --force [tool]."],
	['1', '', '--dig', "Overrides configuration item NO_DIG (resets to default)."],
	['1', '', '--display', "[:[0-9]] Try to get display data out of X (default: 
	display 0)."],
	['1', '', '--dmidecode', "Force use of dmidecode data instead of /sys where 
	relevant 
	(e.g. -M, -B)."],
	['1', '', '--downloader', "Force $self_name to use [curl fetch perl wget] for 
	downloads."],
	['1', '', '--force', "[bt-adapter btmgmt dmidecode hciconfig hddtemp ip 
	ifconfig lsusb meminfo rfkill usb-sys vmstat wmctrl].
	1 or more in comma separated list. Force use of item(s). 
	See --hddtemp, --dmidecode, --wm, --usb-tool, --usb-sys."],
	['1', '', '--hddtemp', "Force use of hddtemp for disk temps."],
	['1', '', '--html-wan', "Overrides configuration item NO_HTML_WAN (resets to 
	default)."],
	['1', '', '--ifconfig', "Force use of ifconfig for IF with -i."],
	);
	if ($use{'update'}){
		push(@$rows, 
		['1', '', '--man', "Install correct man version for dev branch (-U 3) or 
		pinxi using -U."],
		);
	}
	push(@$rows, 
	['1', '', '--no-dig', "Skip dig for WAN IP checks, use downloader program."],
	['1', '', '--no-doas', "Skip internal program use of doas features (not 
	related to starting $self_name with doas)."],
	['1', '', '--no-html-wan', "Skip HTML IP sources for WAN IP checks, use dig 
	only, or nothing if --no-dig."],
	);
	if ($use{'update'}){
		push(@$rows, 
		['1', '', '--no-man', "Disable man install for all -U update actions."],
		);
	}
	push(@$rows, 
	['1', '', '--no-ssl', "Skip SSL certificate checks for all downloader actions 
	(Wget/Fetch/Curl/Perl-HTTP::Tiny)."],
	['1', '', '--no-sudo', "Skip internal program use of sudo features (not 
	related to starting $self_name with sudo)."],
	['1', '', '--rpm', "Force use of disabled package manager counts for packages 
	feature with -rx/-Ix. RPM disabled by default due to slow to massive rpm 
	package query times."],
	['1', '', '--sensors-default', "Removes configuration item SENSORS_USE and 
	SENSORS_EXCLUDE. Same as default behavior."],
	['1', '', '--sensors-exclude', "[sensor[s] name, comma separated] Exclude 
	supplied sensor array[s] for -s output (lm-sensors, /sys. Linux only)."],
	['1', '', '--sensors-use', "[sensor[s] name, comma separated] Use only 
	supplied sensor array[s] for -s output (lm-sensors, /sys. Linux only)."],
	['1', '', '--sleep', "[0-x.x] Change CPU sleep time, in seconds, for -C 
	(default:^$cpu_sleep). Allows system to catch up and show a more accurate CPU 
	use. Example:^$self_name^-Cxxx^--sleep^0.15"],
	['1', '', '--tty', "Forces irc flag to false. Generally useful if $self_name 
	is running inside of another tool like Chef or MOTD and returns corrupted 
	color codes. Please see man page or file an issue if you need to use this 
	flag. Must use -y [width] option if you want a specific output width. Always 
	put this option first in an option list. See -Z for disabling output filters 
	as well."],
	['1', '', '--usb-sys', "Force USB data to use only /sys as data source (Linux 
	only)."],
	['1', '', '--usb-tool', "Force USB data to use lsusb as data source [default]
	(Linux only)."],
	['1', '', '--wan-ip-url', "[URL] Skips dig, uses supplied URL for WAN IP (-i). 
	URL output must end in the IP address. See man. 
	Example:^$self_name^-i^--wan-ip-url^https://yoursite.com/remote-ip"],
	['1', '', '--wm', "Force wm: to use wmctrl as data source. Default uses ps."],
	['0', '', '', $line ],
	['0', '', '', "Debugging Options:"],
	['1', '', '--dbg', "[1-xx[,1-xx]] Comma separated list of debugger numbers.
	Each triggers specific debugger[s]. See man page or docs."],
	['2', '1', '', "Show downloader output. Turns off quiet mode."],
	['1', '', '--debug', "[1-3|10|11|20-22] Triggers debugging modes."],
	['2', '1-3', '', "On screen debugger output."],
	['2', '10', '', "Basic logging."],
	['2', '11', '', "Full file/system info logging."],
	['1', '', ,'', "The following create a tar.gz file of system data, plus 
	$self_name output. To automatically upload debugger data tar.gz file to 
	ftp.smxi.org: $self_name^--debug^21"],
	['2', '20', '', "Full system data collection: /sys; xorg conf and log data, 
	xrandr, xprop, xdpyinfo, glxinfo etc.; data from dev, disks,  
	${partition_string}s, etc."],
	['2', '21', '', "Upload debugger dataset to $self_name debugger server 
	automatically, removes debugger data directory, leaves tar.gz debugger file."],
	['2', '22', '', "Upload debugger dataset to $self_name debugger server 
	automatically, removes debugger data directory and debugger tar.gz file."],
	# ['1', '', '--debug-filter', "Add -z flag to debugger $self_name optiions."],
	['1', '', '--debug-id', "[short-string] Add given string to debugger file 
	name. Helps identify source of debugger dataset. Use with --debug 20-22."],
	['1', '', '--debug-proc', "Force debugger parsing of /proc as sudo/doas/root."],
	['1', '', '--debug-proc-print', "To locate file that /proc debugger hangs on."],
	['1', '', '--debug-no-exit', "Skip exit on error to allow completion."],
	['1', '', '--debug-no-proc', "Skip /proc debugging in case of a hang."],
	['1', '', '--debug-no-sys', "Skip /sys debugging in case of a hang."],
	['1', '', '--debug-sys', "Force PowerPC debugger parsing of /sys as 
	sudo/doas/root."],
	['1', '', '--debug-sys-print', "To locate file that /sys debugger hangs on."],
	['1', '', '--ftp', "Use with --debugger 21 to trigger an alternate FTP server
	for upload. Format:^[ftp.xx.xx/yy]. Must include a remote directory to upload 
	to. Example:^$self_name^--debug^21^--ftp^ftp.myserver.com/incoming"],
	['0', '', '', "$line"],
	);
	print_basic($rows); 
	exit 0; # shell true
}

sub show_version {
	# if not in PATH could be either . or directory name, no slash starting
	my $working_path=$self_path;
	my ($link,$self_string);
	my $rows = [];
	Cwd->import('getcwd'); # no point loading this on top use, we only use getcwd here
	if ($working_path eq '.'){
		$working_path = getcwd();
	}
	elsif ($working_path !~ /^\//){
		$working_path = getcwd() . "/$working_path";
	}
	$working_path =~ s%/$%%;
	# handle if it's a symbolic link, rare, but can happen with directories 
	# in irc clients which would only matter if user starts inxi with -! 30 override 
	# in irc client
	if (-l "$working_path/$self_name"){
		$link="$working_path/$self_name";
		$working_path = readlink "$working_path/$self_name";
		$working_path =~ s/[^\/]+$//;
	}
	# strange output /./ ending, but just trim it off, I don't know how it happens
	$working_path =~ s%/\./%/%;
	push(@$rows, [ 0, '', '', "$self_name $self_version-$self_patch ($self_date)"]);
	if (!$b_irc && !$show{'version-short'}){
		push(@$rows, [ 0, '', '', '']);
		my $year = (split/-/, $self_date)[0];
		push(@$rows, 
		[ 0, '', '', "Copyright^(C)^2008-$year^Harald^Hope^aka^h2"],
		[ 0, '', '', "Forked from Infobash 3.02: Copyright^(C)^2005-2007^Michiel^de^Boer^aka^locsmif." ],
		[ 0, '', '', "Using Perl version: $]"],
		[ 0, '', '', "Program Location: $working_path" ],
		);
		if ($link){
			push(@$rows, [ 0, '', '', "Started via symbolic link: $link" ]);
		}
		push(@$rows, 
		[ 0, '', '', '' ],
		[ 0, '', '', "Website:^https://codeberg.org/smxi/inxi^or^https://smxi.org/" ],
		[ 0, '', '', "IRC:^irc.oftc.net channel:^#smxi" ],
		[ 0, '', '', "Forums:^https://techpatterns.com/forums/forum-33.html" ],
		[ 0, '', '', '' ],
		[ 0, '', '', "This program is free software; you can redistribute it and/or modify 
		it under the terms of the GNU General Public License as published by the Free Software 
		Foundation; either version 3 of the License, or (at your option) any later version. 
		(https://www.gnu.org/licenses/gpl.html)" ]
		);
	}
	print_basic($rows); 
	exit 0 if !$show{'version-short'} || $show{'short'}; # shell true
}

########################################################################
#### STARTUP DATA
########################################################################

## StartClient
{
package CheckTools;
my (%commands);

sub set {
	eval $start if $b_log;
	set_commands();
	my ($action,$program,$message,@data);
	foreach my $test (keys %commands){
		($action,$program) = ('use','');
		$message = main::message('tool-present');
		if ($commands{$test}->[1] && (
			($commands{$test}->[1] eq 'linux' && $os ne 'linux') || 
			($commands{$test}->[1] eq 'bsd' && $os eq 'linux'))){
			$action = 'platform';
		}
		elsif ($program = main::check_program($test)){
			# > 0 means error in shell
			# my $cmd = "$program $commands{$test} >/dev/null";
			# print "$cmd\n";
			$pci_tool = $test if $test =~ /pci/;
			# this test is not ideal because other errors can make program fail, but
			# we can't test for root since could be say, wheel permissions needed
			if ($commands{$test}->[0] eq 'exec-sys'){
				$action = 'permissions' if system("$program $commands{$test}->[2] >/dev/null 2>&1");
			}
			elsif ($commands{$test}->[0] eq 'exec-string'){
				@data = main::grabber("$program $commands{$test}->[2] 2>&1");
				# dmidecode errors are so specific it gets its own section
				# also sets custom dmidecode error messages
				if ($test eq 'dmidecode'){
					$action = set_dmidecode(\@data) if scalar @data < 15;
				}
				elsif (grep { $_ =~ /$commands{$test}->[3]/i } @data){
					$action = 'permissions';
				}
			}
		}
		else {
			$action = 'missing';
		}
		$alerts{$test}->{'action'} = $action;
		$alerts{$test}->{'path'} = $program;
		if ($action eq 'missing'){
			$alerts{$test}->{'message'} = main::message('tool-missing-recommends',"$test");
		}
		elsif ($action eq 'permissions'){
			$alerts{$test}->{'message'} = main::message('tool-permissions',"$test");
		}
		elsif ($action eq 'platform'){
			$alerts{$test}->{'message'} = main::message('tool-missing-os', $uname[0] . " $test");
		}
	}
	print Data::Dumper::Dumper \%alerts if $dbg[25];
	set_fake_bsd_tools() if $fake{'bsd'};
	eval $end if $b_log;
}

sub set_dmidecode {
	my ($data) = @_;
	my $action = 'use';
	if ($b_root){
		foreach (@$data){
			# don't need first line or scanning /dev/mem lines
			if (/^(# dmi|Scanning)/){
				next;
			}
			elsif ($_ =~ /No SMBIOS/i){
				$action = 'smbios';
				last;
			}
			elsif ($_ =~ /^\/dev\/mem: Operation/i){
				$action = 'no-data';
				last;
			}
			else {
				$action = 'unknown-error';
				last;
			}
		}
	}
	else {
		if (grep {$_ =~ /(^\/dev\/mem: Permission|Permission denied)/i } @$data){
			$action = 'permissions';
		}
		else {
			$action = 'unknown-error';
		}
	}
	if ($action ne 'use' && $action ne 'permissions'){
		if ($action eq 'smbios'){
			$alerts{'dmidecode'}->{'message'} = main::message('dmidecode-smbios');
		}
		elsif ($action eq 'no-data'){
			$alerts{'dmidecode'}->{'message'} = main::message('dmidecode-dev-mem');
		}
		elsif ($action eq 'unknown-error'){
			$alerts{'dmidecode'}->{'message'} = main::message('tool-unknown-error','dmidecode');
		}
	}
	return $action;
}

sub set_commands {
	# note: gnu/linux has sysctl so it may be used that for something if present
	# there is lspci for bsds so doesn't hurt to check it
	if (!$bsd_type){
		if ($use{'pci'}){
			$commands{'lspci'} = ['exec-sys','','-n'];
		}
		if ($use{'logical'}){
			$commands{'lvs'} = ['exec-sys','',''];
		}
		if ($use{'udevadm'}){
			$commands{'udevadm'} = ['missing','',''];
		}
	}
	else {
		if ($use{'pci'}){
			$commands{'pciconf'} = ['exec-sys','','-l'];
			$commands{'pcictl'} = ['exec-sys','',' pci0 list'];
			$commands{'pcidump'} = ['exec-sys','',''];
		}
		if ($use{'sysctl'}){
			# note: there is a case of kernel.osrelease but it's a linux distro
			$commands{'sysctl'} = ['exec-sys','','kern.osrelease'];
		}
		if ($use{'bsd-partition'}){
			$commands{'bioctl'} = ['missing','',''];
			$commands{'disklabel'} = ['missing','',''];
			$commands{'fdisk'} = ['missing','',''];
			$commands{'gpart'} = ['missing','',''];
		}
	}
	if ($use{'dmidecode'}){
		$commands{'dmidecode'} = ['exec-string','','-t chassis -t baseboard -t processor',''];
	}
	if ($use{'usb'}){
		# note: lsusb ships in FreeBSD ports sysutils/usbutils
		$commands{'lsusb'} = ['missing','','',''];
		# we want these set for various null bsd data tests
		$commands{'usbconfig'} = ['exec-string','bsd','list','permissions'];
		$commands{'usbdevs'} = ['missing','bsd','',''];
	}
	if ($show{'bluetooth'}){
		$commands{'bluetoothctl'} = ['missing','linux','',''];
		# bt-adapter hangs when bluetooth service is disabled
		$commands{'bt-adapter'} = ['missing','linux','',''];
		# btmgmt enters its own shell with no options given
		$commands{'btmgmt'} = ['missing','linux','',''];
		$commands{'hciconfig'} = ['missing','linux','',''];
	}
	if ($show{'sensor'}){
		$commands{'sensors'} = ['missing','linux','',''];
	}
	if ($show{'ip'} || ($bsd_type && $show{'network-advanced'})){
		$commands{'ip'} = ['missing','linux','',''];
		$commands{'ifconfig'} = ['missing','','',''];
	}
	# can't check permissions since we need to know the partition/disc
	if ($use{'block-tool'}){
		$commands{'blockdev'} = ['missing','linux','',''];
		$commands{'lsblk'} = ['missing','linux','',''];
	}
	if ($use{'btrfs'}){
		$commands{'btrfs'} = ['missing','linux','',''];
	}
	if ($use{'mdadm'}){
		$commands{'mdadm'} = ['missing','linux','',''];
	}
	if ($use{'smartctl'}){
		$commands{'smartctl'} = ['missing','','',''];
	}
	if ($show{'unmounted'}){
		$commands{'disklabel'} = ['missing','bsd','xx'];
	}
}

# only for dev/debugging BSD 
sub set_fake_bsd_tools {
	$system_files{'dmesg-boot'} = '/var/run/dmesg.boot' if $fake{'dboot'};
	$alerts{'sysctl'}->{'action'} = 'use' if $fake{'sysctl'};
	if ($fake{'pciconf'} || $fake{'pcictl'} || $fake{'pcidump'}){
		$alerts{'pciconf'}->{'action'} = 'use' if $fake{'pciconf'};
		$alerts{'pcictl'}->{'action'} = 'use' if $fake{'pcictl'};
		$alerts{'pcidump'}->{'action'} = 'use' if $fake{'pcidump'};
		$alerts{'lspci'} = {
		'action' => 'missing',
		'message' => 'Required program lspci not available',
		};
	}
	if ($fake{'usbconfig'} || $fake{'usbdevs'}){
		$alerts{'usbconfig'}->{'action'} = 'use' if $fake{'usbconfig'};
		$alerts{'usbdevs'}->{'action'} = 'use' if $fake{'usbdevs'};
		$alerts{'lsusb'} = {
		'action' => 'missing',
		'message' => 'Required program lsusb not available',
		};
	}
	if ($fake{'disklabel'}){
		$alerts{'disklabel'}->{'action'} = 'use';
	}
}
}

sub  {
	### LOCALIZATION - DO NOT CHANGE! ###
	# set to default LANG to avoid locales errors with , or .
	# Make sure every program speaks English.
	$ENV{'LANG'}='C';
	$ENV{'LC_Aset_basicsLL'}='C';
	# remember, perl uses the opposite t/f return as shell!!!
	# some versions of busybox do not have tty, like openwrt
	$b_irc = 1 if (check_program('tty') && system('tty >/dev/null'));
	# print "birc: $b_irc\n";
	# with X, DISPLAY sets, then check Wayland, other DE/WM sessions
	if ($ENV{'DISPLAY'} || $ENV{'WAYLAND_DISPLAY'} || 
	$ENV{'XDG_CURRENT_DESKTOP'} || $ENV{'DESKTOP_SESSION'}){
		$b_display = 1;
	}
	$b_root = $< == 0; # root UID 0, all others > 0
	$dl{'dl'} = 'curl';
	$dl{'curl'} = 1;
	$dl{'fetch'} = 1;
	$dl{'tiny'} = 1; # note: two modules needed, tested for in set_downloader
	$dl{'wget'} = 1;
	$client{'console-irc'} = 0;
	$client{'dcop'} = (check_program('dcop')) ? 1 : 0;
	$client{'qdbus'} = (check_program('qdbus')) ? 1 : 0;
	$client{'konvi'} = 0;
	$client{'name'} = '';
	$client{'name-print'} = '';
	$client{'su-start'} = ''; # shows sudo/su
	$client{'version'} = '';
	$client{'whoami'} = getpwuid($<) || '';
	$colors{'default'} = 2;
	$show{'partition-sort'} = 'id'; # sort order for partitions
	@raw_logical = (0,0,0);
	$ppid = getppid();
	# seen case where $HOME not set
	if (!$ENV{'HOME'}){
		if (my $who = qx(whoami)){
			if (-d "/$who"){
				$ENV{'HOME'} = "/$who";} # root
			elsif (-d "/home/$who"){
				$ENV{'HOME'} = "/home/$who";}
			elsif (-d "/usr/home/$who"){
				$ENV{'HOME'} = "/usr/home/$who";}
			# else give up, we're not going to have any luck here
		}
	}
}

sub set_display_size {
	## sometimes tput will trigger an error (mageia) if irc client
	if (!$b_irc){
		if (my $program = check_program('tput')){
			# Arch urxvt: 'tput: unknown terminal "rxvt-unicode-256color"'
			# trips error if use qx(); in FreeBSD, if you use 2>/dev/null 
			# it makes default value 80x24, who knows why?
			chomp($size{'term-cols'} = qx{$program cols});
			chomp($size{'term-lines'} = qx{$program lines});
		}
		# print "tc: $size{'term-cols'} cmc: $size{'console'}\n";
		# double check, just in case it's missing functionality or whatever
		if (!is_int($size{'term-cols'} || $size{'term-cols'} == 0)){ 
			$size{'term-cols'} = 80;
		}
		if (!is_int($size{'term-lines'} || $size{'term-lines'} == 0)){ 
			$size{'term-lines'} = 24;
		}
	}
	# this lets you set different size for in or out of display server
	if (!$b_display && $size{'no-display'}){
		$size{'console'} = $size{'no-display'};
	}
	# term_cols is set in top globals, using tput cols
	# print "tc: $size{'term-cols'} cmc: $size{'console'}\n";
	if ($size{'term-cols'} < $size{'console'}){
		$size{'console'} = $size{'term-cols'};
	}
	# adjust, some terminals will wrap if output cols == term cols
	$size{'console'} = ($size{'console'} - 1);
	# echo cmc: $size{'console'}
	# comes after source for user set stuff
	if (!$b_irc){
		$size{'max-cols'} = $size{'console'};
	}
	else {
		$size{'max-cols'} = $size{'irc'};
	}
	# for -V/-h overrides
	$size{'max-cols-basic'} = $size{'max-cols'};
	# print "tc: $size{'term-cols'} cmc: $size{'console'} cm: $size{'max-cols'}\n";
}

sub set_os {
	@uname = uname();
	$os = lc($uname[0]);
	$cpu_arch = lc($uname[-1]);
	if ($cpu_arch =~ /arm|aarch/){
		$risc{'arm'} = 1;
		$risc{'id'} = 'arm';}
	elsif ($cpu_arch =~ /mips/){
		$risc{'mips'} = 1;
		$risc{'id'} = 'mips';}
	elsif ($cpu_arch =~ /power|ppc/){
		$risc{'ppc'} = 1;
		$risc{'id'} = 'ppc';}
	elsif ($cpu_arch =~ /riscv/){
		$risc{'riscv'} = 1;
		$risc{'id'} = 'riscv';}
	elsif ($cpu_arch =~ /(sparc|sun4[uv])/){
		$risc{'sparc'} = 1;
		$risc{'id'} = 'sparc';}
	# aarch32 mips32, i386. centaur/via/intel/amd handled in cpu
	if ($cpu_arch =~ /(armv[1-7]|32|[23456]86)/){
		$bits_sys = 32;
	}
	elsif ($cpu_arch =~ /(alpha|64|e2k|sparc_v9|sun4[uv]|ultrasparc)/){
		$bits_sys = 64;
		# force to string e2k, and also in case we need that ID changed
		$cpu_arch = 'elbrus' if $cpu_arch =~ /e2k|elbrus/;
	}
	# set some less common scenarios
	if ($os =~ /cygwin/){
		$windows{'cygwin'} = 1;
	}
	elsif (-e '/usr/lib/wsl/drivers'){
		$windows{'wsl'} = 1;
	}
	elsif (-e '/system/build.prop'){
		$b_android = 1;
	}
	if ($os =~ /(aix|bsd|cosix|dragonfly|darwin|hp-?ux|indiana|illumos|irix|sunos|solaris|ultrix|unix)/){
		if ($os =~ /openbsd/){
			$os = 'openbsd';
		}
		elsif ($os =~ /darwin/){
			$os = 'darwin';
		}
		# NOTE: most tests internally are against !$bsd_type
		if ($os =~ /kfreebsd/){
			$bsd_type = 'debian-bsd';
		}
		else {
			$bsd_type = $os;
		}
	}
}

# Sometimes users will have more PATHs local to their setup, so we want those
# too.
sub set_path {
	# Extra path variable to make execute failures less likely, merged below
	my (@path);
	# NOTE: recent Xorg's show error if you try /usr/bin/Xorg -version but work 
	# if you use the /usr/lib/xorg-server/Xorg path.
	my @test = qw(/sbin /bin /usr/sbin /usr/bin /usr/local/sbin /usr/local/bin 
	/usr/X11R6/bin);
	foreach (@test){
		push(@paths,$_) if -d $_;
	}
	@path = split(':', $ENV{'PATH'}) if $ENV{'PATH'};
	# print "paths: @paths\nPATH: $ENV{'PATH'}\n";
	# Create a difference of $PATH and $extra_paths and add that to $PATH:
	foreach my $id (@path){
		if (-d $id && !(grep {/^$id$/} @paths) && $id !~ /(game)/){
			push(@paths, $id);
		}
	}
	# print "paths: \n", join("\n", @paths),"\n";
}

sub set_sep {
	if ($b_irc){
		# too hard to read if no colors, so force that for users on irc
		if ($colors{'scheme'} == 0){
			$sep{'s1'} = $sep{'s1-console'};
			$sep{'s2'} = $sep{'s2-console'};
		}
		else {
			$sep{'s1'} = $sep{'s1-irc'};
			$sep{'s2'} = $sep{'s2-irc'};
		}
	}
	else {
		$sep{'s1'} = $sep{'s1-console'};
		$sep{'s2'} = $sep{'s2-console'};
	}
}

# Important: -n makes it non interactive, no prompt for password
# only use doas/sudo if not root, -n option requires sudo -V 1.7 or greater. 
# for some reason sudo -n with < 1.7 in Perl does not print to stderr
# sudo will just error out which is the safest course here for now,
# otherwise that interactive sudo password thing is too annoying
sub set_sudo {
	if (!$b_root){
		my ($path);
		if (!$force{'no-doas'} && ($path = check_program('doas'))){
			$sudoas = "$path -n ";
		}
		elsif (!$force{'no-sudo'} && ($path = check_program('sudo'))){
			my @data = ProgramData::full('sudo');
			$data[1] =~ s/^([0-9]+\.[0-9]+).*/$1/;
			# print "sudo v: $data[1]\n";
			$sudoas = "$path -n " if is_numeric($data[1]) && $data[1] >= 1.7;
		}
	}
}

sub set_system_files {
	my %files = (
	'asound-cards' => '/proc/asound/cards',
	'asound-modules' => '/proc/asound/modules',
	'asound-version' => '/proc/asound/version',
	'dmesg-boot' => '/var/run/dmesg.boot',
	'proc-cmdline' => '/proc/cmdline',
	'proc-cpuinfo' => '/proc/cpuinfo',
	'proc-mdstat' => '/proc/mdstat',
	'proc-meminfo' => '/proc/meminfo',
	'proc-modules' => '/proc/modules', # not used
	'proc-mounts' => '/proc/mounts',# not used
	'proc-partitions' => '/proc/partitions',
	'proc-scsi' => '/proc/scsi/scsi',
	'proc-version' => '/proc/version',
	# note: 'xorg-log' is set in set_xorg_log() only if -G is triggered
	);
	foreach (keys %files){
		$system_files{$_} = (-e $files{$_}) ? $files{$_} : '';
	}
}

sub set_user_paths {
	my ($b_conf,$b_data);
	# this needs to be set here because various options call the parent 
	# initialize function directly.
	$self_path = $0;
	$self_path =~ s/[^\/]+$//;
	# print "0: $0 sp: $self_path\n";
	# seen case where $HOME not set
	if ($ENV{'XDG_CONFIG_HOME'}){
		$user_config_dir=$ENV{'XDG_CONFIG_HOME'};
		$b_conf=1;
	}
	elsif (-d "$ENV{'HOME'}/.config"){
		$user_config_dir="$ENV{'HOME'}/.config";
		$b_conf=1;
	}
	else {
		$user_config_dir="$ENV{'HOME'}/.$self_name";
	}
	if ($ENV{'XDG_DATA_HOME'}){
		$user_data_dir="$ENV{'XDG_DATA_HOME'}/$self_name";
		$b_data=1;
	}
	elsif (-d "$ENV{'HOME'}/.local/share"){
		$user_data_dir="$ENV{'HOME'}/.local/share/$self_name";
		$b_data=1;
	}
	else {
		$user_data_dir="$ENV{'HOME'}/.$self_name";
	}
	# note, this used to be created/checked in specific instance, but we'll just 
	# do it universally so it's done at script start.
	if (! -d $user_data_dir){
		mkdir $user_data_dir;
		# system "echo", "Made: $user_data_dir";
	}
	if ($b_conf && -f "$ENV{'HOME'}/.$self_name/$self_name.conf"){
		# system 'mv', "-f $ENV{'HOME'}/.$self_name/$self_name.conf", $user_config_dir;
		# print "WOULD: Moved $self_name.conf from $ENV{'HOME'}/.$self_name to $user_config_dir\n";
	}
	if ($b_data && -d "$ENV{'HOME'}/.$self_name"){
		# system 'mv', '-f', "$ENV{'HOME'}/.$self_name/*", $user_data_dir;
		# system 'rm', '-Rf', "$ENV{'HOME'}/.$self_name";
		# print "WOULD: Moved data dir $ENV{'HOME'}/.$self_name to $user_data_dir\n";
	}
	$fake_data_dir = "$ENV{'HOME'}/bin/scripts/inxi/data";
	$log_file="$user_data_dir/$self_name.log";
	# system 'echo', "$ENV{'HOME'}/.$self_name/* $user_data_dir";
	# print "scd: $user_config_dir sdd: $user_data_dir \n";
}

sub set_xorg_log {
	eval $start if $b_log;
	my (@temp,@x_logs);
	my ($file_holder,$time_holder,$x_mtime) = ('',0,0);
	# NOTE: other variations may be /var/run/gdm3/... but not confirmed
	# worry about we are just going to get all the Xorg logs we can find,
	# and not which is 'right'. Xorg was XFree86 earlier, only in /var/log.
	@temp = globber('/var/log/{Xorg,XFree86}.*.log');
	push(@x_logs, @temp) if @temp;
	@temp = globber('/var/lib/gdm/.local/share/xorg/Xorg.*.log');
	push(@x_logs, @temp) if @temp;
	@temp = globber($ENV{'HOME'} . '/.local/share/xorg/Xorg.*.log',);
	push(@x_logs, @temp) if @temp;
	# root will not have a /root/.local/share/xorg directory so need to use a 
	# user one if we can find one.
	if ($b_root){
		@temp = globber('/home/*/.local/share/xorg/Xorg.*.log');
		push(@x_logs, @temp) if @temp;
	}
	foreach (@x_logs){
		if (-r $_){
			my $src_info = File::stat::stat("$_");
			# print "$_\n";
			if ($src_info){
				$x_mtime = $src_info->mtime;
				# print $_ . ": $x_time" . "\n";
				if ($x_mtime > $time_holder){
					$time_holder = $x_mtime;
					$file_holder = $_;
				}
			}
		}
	}
	if (!$file_holder && check_program('xset')){
		my $data = qx(xset q 2>/dev/null);
		foreach (split('\n', $data)){
			if ($_ =~ /Log file/i){
				$file_holder = get_piece($_,3);
				last;
			}
		}
	}
	print "Xorg log file: $file_holder\nLast modified: $time_holder\n" if $dbg[14];
	log_data('data',"Xorg log file: $file_holder") if $b_log;
	$system_files{'xorg-log'} = $file_holder;
	eval $end if $b_log;
}

########################################################################
#### UTILITIES
########################################################################

#### -------------------------------------------------------------------
#### COLORS
#### -------------------------------------------------------------------

## args: 0: the type of action, either integer, count, or full
sub get_color_scheme {
	eval $start if $b_log;
	my ($type) = @_;
	my $color_schemes = [
	[qw(EMPTY EMPTY EMPTY)],
	[qw(NORMAL NORMAL NORMAL)],
	# for dark OR light backgrounds
	[qw(BLUE NORMAL NORMAL)],
	[qw(BLUE RED NORMAL)],
	[qw(CYAN BLUE NORMAL)],
	[qw(DCYAN NORMAL NORMAL)],
	[qw(DCYAN BLUE NORMAL)],
	[qw(DGREEN NORMAL NORMAL)],
	[qw(DYELLOW NORMAL NORMAL)],
	[qw(GREEN DGREEN NORMAL)],
	[qw(GREEN NORMAL NORMAL)],
	[qw(MAGENTA NORMAL NORMAL)],
	[qw(RED NORMAL NORMAL)],
	# for light backgrounds
	[qw(BLACK DGREY NORMAL)],
	[qw(DBLUE DGREY NORMAL)],
	[qw(DBLUE DMAGENTA NORMAL)],
	[qw(DBLUE DRED NORMAL)],
	[qw(DBLUE BLACK NORMAL)],
	[qw(DGREEN DYELLOW NORMAL)],
	[qw(DYELLOW BLACK NORMAL)],
	[qw(DMAGENTA BLACK NORMAL)],
	[qw(DCYAN DBLUE NORMAL)],
	# for dark backgrounds
	[qw(WHITE GREY NORMAL)],
	[qw(GREY WHITE NORMAL)],
	[qw(CYAN GREY NORMAL)],
	[qw(GREEN WHITE NORMAL)],
	[qw(GREEN YELLOW NORMAL)],
	[qw(YELLOW WHITE NORMAL)],
	[qw(MAGENTA CYAN NORMAL)],
	[qw(MAGENTA YELLOW NORMAL)],
	[qw(RED CYAN NORMAL)],
	[qw(RED WHITE NORMAL)],
	[qw(BLUE WHITE NORMAL)],
	# miscellaneous
	[qw(RED BLUE NORMAL)],
	[qw(RED DBLUE NORMAL)],
	[qw(BLACK BLUE NORMAL)],
	[qw(BLACK DBLUE NORMAL)],
	[qw(NORMAL BLUE NORMAL)],
	[qw(BLUE MAGENTA NORMAL)],
	[qw(DBLUE MAGENTA NORMAL)],
	[qw(BLACK MAGENTA NORMAL)],
	[qw(MAGENTA BLUE NORMAL)],
	[qw(MAGENTA DBLUE NORMAL)],
	];
	eval $end if $b_log;
	if ($type eq 'count'){
		return scalar @$color_schemes;
	}
	if ($type eq 'full'){
		return $color_schemes;
	}
	else {
		# print Dumper $color_schemes->[$type];
		return $color_schemes->[$type];
	}
}

sub set_color_scheme {
	eval $start if $b_log;
	my ($scheme) = @_;
	$colors{'scheme'} = $scheme;
	my $index = ($b_irc) ? 1 : 0; # defaults to non irc
	# NOTE: qw(...) kills the escape, it is NOT the same as using 
	# Literal "..", ".." despite docs saying it is.
	my %color_palette = (
	'EMPTY' => [ '', '' ],
	'DGREY' => [ "\e[1;30m", "\x0314" ],
	'BLACK' => [ "\e[0;30m", "\x0301" ],
	'RED' => [ "\e[1;31m", "\x0304" ],
	'DRED' => [ "\e[0;31m", "\x0305" ],
	'GREEN' => [ "\e[1;32m", "\x0309" ],
	'DGREEN' => [ "\e[0;32m", "\x0303" ],
	'YELLOW' => [ "\e[1;33m", "\x0308" ],
	'DYELLOW' => [ "\e[0;33m", "\x0307" ],
	'BLUE' => [ "\e[1;34m", "\x0312" ],
	'DBLUE' => [ "\e[0;34m", "\x0302" ],
	'MAGENTA' => [ "\e[1;35m", "\x0313" ],
	'DMAGENTA' => [ "\e[0;35m", "\x0306" ],
	'CYAN' => [ "\e[1;36m", "\x0311" ],
	'DCYAN' => [ "\e[0;36m", "\x0310" ],
	'WHITE' => [ "\e[1;37m", "\x0300" ],
	'GREY' => [ "\e[0;37m", "\x0315" ],
	'NORMAL' => [ "\e[0m", "\x03" ],
	);
	my $color_scheme = get_color_scheme($colors{'scheme'});
	$colors{'c1'} = $color_palette{$color_scheme->[0]}[$index];
	$colors{'c2'} = $color_palette{$color_scheme->[1]}[$index];
	$colors{'cn'} = $color_palette{$color_scheme->[2]}[$index];
	# print Dumper \@scheme;
	# print "$colors{'c1'}here$colors{'c2'} we are!$colors{'cn'}\n";
	eval $end if $b_log;
}

sub set_colors {
	eval $start if $b_log;
	# it's already been set with -c 0-43
	if (exists $colors{'c1'}){
		return 1;
	}
	# This let's user pick their color scheme. For IRC, only shows the color 
	# schemes, no interactive. The override value only will be placed in user 
	# config files. /etc/inxi.conf can also override
	if (exists $colors{'selector'}){
		my $ob_selector = SelectColors->new($colors{'selector'});
		$ob_selector->select_schema();
		return 1;
	}
	# set the default, then override as required
	my $color_scheme = $colors{'default'};
	# these are set in user configs
	if (defined $colors{'global'}){
		$color_scheme = $colors{'global'};
	}
	else {
		if ($b_irc){
			if (defined $colors{'irc-virt-term'} && $b_display && $client{'console-irc'}){
				$color_scheme = $colors{'irc-virt-term'};
			}
			elsif (defined $colors{'irc-console'} && !$b_display){
				$color_scheme = $colors{'irc-console'};
			}
			elsif (defined $colors{'irc-gui'}){
				$color_scheme = $colors{'irc-gui'};
			}
		}
		else {
			if (defined $colors{'console'} && !$b_display){
				$color_scheme = $colors{'console'};
			}
			elsif (defined $colors{'virt-term'}){
				$color_scheme = $colors{'virt-term'};
			}
		}
	}
	# force 0 for | or > output, all others prints to irc or screen
	if (!$b_irc && !$force{'colors'} && ! -t STDOUT){
		$color_scheme = 0;
	}
	set_color_scheme($color_scheme);
	eval $end if $b_log;
}

## SelectColors
{
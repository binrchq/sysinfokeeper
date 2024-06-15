package SystemDebugger;
my $option = 'main';
my ($data_dir,$debug_dir,$debug_gz,$parse_src,$upload) = ('','','','','');
my @content; 
my $b_debug = 0;
my $b_delete_dir = 1;

# args: 0: type; 1: upload
sub new {
	my $class = shift;
	($option) = @_;
	my $self = {};
	# print "$f\n";
	# print "$option\n";
	return bless $self, $class;
}

sub run_debugger {
	print "Starting $self_name debugging data collector...\n";
	check_required_items();
	create_debug_directory();
	print "Note: for dmidecode, smartctl, lvm data you must be root.\n" if !$b_root;
	print $line3;
	if (!$b_debug){
		audio_data();
		bluetooth_data();
		disk_data();
		display_data();
		network_data();
		perl_modules();
		system_data();
	}
	system_files();
	print $line3;
	if (!$b_debug){
		# note: android has unreadable /sys, but -x and -r tests pass
		# main::globber('/sys/*') && 
		if ($debugger{'sys'} && main::count_dir_files('/sys')){
			build_tree('sys');
			# kernel crash, not sure what creates it, for ppc, as root
			if ($debugger{'sys'} && ($debugger{'sys-force'} || !$b_root || !$risc{'ppc'})){
				sys_traverse_data();
			}
		}
		else {
			print "Skipping /sys data collection.\n";
		}
		print $line3;
		# note: proc has some files that are apparently kernel processes, I've tried 
		# filtering them out but more keep appearing, so only run proc debugger if not root
		if (!$debugger{'no-proc'} && (!$b_root || $debugger{'proc'}) && -d '/proc' && main::count_dir_files('/proc')){
			build_tree('proc');
			proc_traverse_data();
		}
		else {
			print "Skipping /proc data collection.\n";
		}
		print $line3;
	}
	run_self();
	print $line3;
	compress_dir();
}

sub check_required_items {
	print "Loading required debugger Perl File:: modules... \n";
	# Fedora/Redhat doesn't include File::Find File::Copy in 
	# core modules. why? Or rather, they deliberately removed them.
	if (main::check_perl_module('File::Find')){
		File::Find->import;
	}
	else {
		main::error_handler('required-module', 'File', 'File::Find');
	}
	if (main::check_perl_module('File::Copy')){
		File::Copy->import;
	}
	else {
		main::error_handler('required-module', 'File', 'File::Copy');
	}
	if (main::check_perl_module('File::Spec::Functions')){
		File::Spec::Functions->import;
	}
	else {
		main::error_handler('required-module', 'File', 'File::Spec::Functions');
	}
	if ($debugger{'level'} > 20){
		if (main::check_perl_module('Net::FTP')){
			Net::FTP->import;
		}
		else {
			main::error_handler('required-module', 'Net', 'Net::FTP');
		}
	}
	print "Checking basic core system programs exist... \n";
	if ($debugger{'level'} > 19){
		# astoundingly, rhel 9 and variants are shipping without tar in minimal install
		if (!main::check_program('tar')){
			main::error_handler('required-program', 'tar', 'debugger');
		}
	}
}

sub create_debug_directory {
	my $host = main::get_hostname();
	$host =~ s/ /-/g;
	$host = 'no-host' if !$host || $host eq 'N/A';
	my ($alt_string,$root_string) = ('','');
	# note: Time::Piece was introduced in perl 5.9.5
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
	$year = $year+1900;
	$mon += 1;
	if (length($sec)  == 1){$sec = "0$sec";}
	if (length($min)  == 1){$min = "0$min";}
	if (length($hour) == 1){$hour = "0$hour";}
	if (length($mon)  == 1){$mon = "0$mon";}
	if (length($mday) == 1){$mday = "0$mday";}
	my $today = "$year-$mon-${mday}_$hour$min$sec";
	# my $date = strftime "-%Y-%m-%d_", localtime;
	if ($b_root){
		$root_string = '-root';
	}
	my $id = ($debugger{'id'}) ? '-' . $debugger{'id'}: '';
	$alt_string = '-' . uc($risc{'id'}) if %risc;
	$alt_string .= "-BSD-$bsd_type" if $bsd_type;
	$alt_string .= '-ANDROID' if $b_android; 
	$alt_string .= '-CYGWIN' if $windows{'cygwin'}; # could be windows arm?
	$alt_string .= '-WSL' if $windows{'wsl'}; # could be windows arm?
	$debug_dir = "$self_name$alt_string-$host$id-$today$root_string-$self_version-$self_patch";
	$debug_gz = "$debug_dir.tar.gz";
	$data_dir = "$user_data_dir/$debug_dir";
	if (-d $data_dir){
		unlink $data_dir or main::error_handler('remove', "$data_dir", "$!");
	}
	mkdir $data_dir or main::error_handler('mkdir', "$data_dir", "$!");
	if (-e "$user_data_dir/$debug_gz"){
		#rmdir "$user_data_dir$debug_gz" or main::error_handler('remove', "$user_data_dir/$debug_gz", "$!");
		print "Failed removing leftover directory:\n$user_data_dir$debug_gz error: $?" if system('rm','-rf',"$user_data_dir$debug_gz");
	}
	print "Debugger data going into:\n$data_dir\n";
}

sub compress_dir {
	print "Creating tar.gz compressed file of this material...\n";
	print "File: $debug_gz\n";
	system("cd $user_data_dir; tar -czf $debug_gz $debug_dir");
	print "Removing $data_dir...\n";
	#rmdir $data_dir or print "failed removing: $data_dir error: $!\n";
	return 1 if !$b_delete_dir;
	if (system('rm','-rf',$data_dir)){
		print "Failed removing: $data_dir\nError: $?\n";
	}
	else {
		print "Directory removed.\n";
	}
}

# NOTE: incomplete, don't know how to ever find out 
# what sound server is actually running, and is in control
sub audio_data {
	my (%data,@files,@files2);
	print "Collecting audio data...\n";
	my @cmds = (
	['aplay', '--version'], # alsa
	['aplay', '-l'], # alsa devices
	['aplay', '-L'], # alsa list of features, can detect active sound server
	['artsd', '-v'], # aRts
	['esd', '-v'], # EsounD, to stderr
	['nasd', '-V'], # NAS
	['jackd', '--version'], # JACK
	['pactl', '--version'], # pulseaudio
	['pactl', 'info'], # pulseaudio, check if running as server: Server Name:
	['pactl', 'list'], # pulseaudio
	['pipewire', '--version'], # pipewire
	['pipewire-alsa', '--version'], # pipewire-alsa - just config files
	['pipewire-pulse', '--version'], # pipewire-pulse
	['pulseaudio', '--version'], # PulseAudio
	['pw-jack', '--version'], # pipewire-jack
	['pw-cli', 'ls'], # pipewire, check if running as server
	['pw-cli', 'info all'],
	);
	run_commands(\@cmds,'audio');
	@files = main::globber('/proc/asound/card*/codec*');
	if (@files){
		my $asound = qx(head -n 1 /proc/asound/card*/codec* 2>&1);
		$data{'proc-asound-codecs'} = $asound;
	}
	else {
		$data{'proc-asound-codecs'} = undef;
	}
	write_data(\%data,'audio');
	@files = (
	'/proc/asound/cards',
	'/proc/asound/version',
	);
	@files2 = main::globber('/proc/asound/*/usbid');
	push(@files,@files2) if @files2;
	copy_files(\@files,'audio');
}

sub bluetooth_data {
	print "Collecting bluetooth data...\n";
	# no warnings 'uninitialized';
	my @cmds = (
	['btmgmt','info'],
	['hciconfig','-a'], # no version
	#['hcidump',''], # hangs sometimes
	['hcitool','dev'],
	['rfkill','--output-all'],
	);
	# these hang if bluetoothd not enabled
	if (@ps_cmd && (grep {m|/bluetoothd|} @ps_cmd)){
		push(@cmds,
		['bt-adapter','--list'], # no version
		['bt-adapter','--info'],
		['bluetoothctl','--version'],
		['bluetoothctl','--list'],
		['bluetoothctl','--show']
		);
	}
	run_commands(\@cmds,'bluetooth');
}

## NOTE: >/dev/null 2>&1 is sh, and &>/dev/null is bash, fix this
# ls -w 1 /sysrs > tester 2>&1
sub disk_data {
	my (%data,@files,@files2);
	print "Collecting dev, label, disk, uuid data, df...\n";
	@files = (
	'/etc/fstab',
	'/etc/mtab',
	'/proc/devices',
	'/proc/mdstat',
	'/proc/mounts',
	'/proc/partitions',
	'/proc/scsi/scsi',
	'/proc/sys/dev/cdrom/info',
	);
	# very old systems
	if (-d '/proc/ide/'){
		my @ides = main::globber('/proc/ide/*/*');
		push(@files, @ides) if @ides;
	}
	else {
		push(@files, '/proc-ide-directory');
	}
	copy_files(\@files, 'disk');
	my @cmds = (
	['blockdev', '--version'],
	['blockdev', '--report'],
	['btrfs', 'fi show'], # no version
	['btrfs', 'filesystem show'],
	['btrfs', 'filesystem show --mounted'],
	# ['btrfs', 'filesystem show --all-devices'],
	['df', '-h -T'], # no need for version, and bsd doesn't have its
	['df', '-h'],
	['df', '-k'],
	['df', '-k -P'],
	['df', '-k -T'],
	['df', '-k -T -P'],
	['df', '-k -T -P -a'],
	['df', '-P'],
	['dmsetup', 'ls --tree'],
	['findmnt', ''],
	['findmnt', '--df --no-truncate'],
	['findmnt', '--list --no-truncate'],
	['gpart', 'list'], # no version
	['gpart', 'show'],
	['gpart', 'status'],
	['ls', '-l /dev'],# core util, don't need version
	# block is for mmcblk / arm devices
	['ls', '-l /dev/block'],
	['ls', '-l /dev/block/bootdevice'],
	['ls', '-l /dev/block/bootdevice/by-name'],
	['ls', '-l /dev/disk'],
	['ls', '-l /dev/disk/by-id'],
	['ls', '-l /dev/disk/by-label'],
	['ls', '-l /dev/disk/by-partlabel'],
	['ls', '-l /dev/disk/by-partuuid'],
	['ls', '-l /dev/disk/by-path'],
	['ls', '-l /dev/disk/by-uuid'],
	# http://comments.gmane.org/gmane.linux.file-systems.zfs.user/2032
	['ls', '-l /dev/disk/by-wwn'],
	['ls', '-l /dev/mapper'],
	['lsblk', '--version'], # important since lsblk has been changing output
	['lsblk', '-fs'],
	['lsblk', '-fsr'],
	['lsblk', '-fsP'],
	['lsblk', '-a'],
	['lsblk', '-aP'],
	['lsblk', '-ar'],
	['lsblk', '-p'],
	['lsblk', '-pr'],
	['lsblk', '-pP'],
	['lsblk', '-r'],
	['lsblk', '-r --output NAME,PKNAME,TYPE,RM,FSTYPE,SIZE,LABEL,UUID,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS'],
	['lsblk', '-rb --output NAME,PKNAME,TYPE,RM,FSTYPE,SIZE,LABEL,UUID,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS'],
	['lsblk', '-rb --output NAME,TYPE,RM,FSTYPE,SIZE,LABEL,UUID,SERIAL,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS,MAJ:MIN,PKNAME'],
	['lsblk', '-Pb --output NAME,PKNAME,TYPE,RM,FSTYPE,SIZE'],
	['lsblk', '-Pb --output NAME,TYPE,RM,FSTYPE,SIZE,LABEL,UUID,SERIAL,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS'],
	# this should always be the live command used internally:
	['lsblk', '-bP --output NAME,TYPE,RM,FSTYPE,SIZE,LABEL,UUID,SERIAL,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS,MAJ:MIN,PKNAME'],
	['lvdisplay', '--version'],
	['lvdisplay', '-c'],
	['lvdisplay', '-cv'],
	['lvdisplay', '-cv --segments'],
	['lvdisplay', '-m --segments'],
	['lvdisplay', '-ma --segments'],
	['lvs', '--version'],
	['lvs', '--separator :'],
	['lvs', '--separator : --segments'],
	['lvs', '-o +devices --separator : --segments'],
	['lvs', '-o +devices -v --separator : --segments'],
	['lvs', '-o +devices -av --separator : --segments'],
	['lvs', '-o +devices -aPv --separator : --segments'],
	# LSI raid https://hwraid.le-vert.net/wiki/LSIMegaRAIDSAS
	['megacli', '-AdpAllInfo -aAll'], # no version
	['megacli', '-LDInfo -L0 -a0'],
	['megacli', '-PDList -a0'],
	['megaclisas-status', ''], # no version
	['megaraidsas-status', ''],
	['megasasctl', ''],
	['mount', ''],
	['nvme', 'present'], # no version
	['pvdisplay', '--version'],
	['pvdisplay', '-c'],
	['pvdisplay', '-cv'],
	['pvdisplay', '-m'],
	['pvdisplay', '-ma'],
	['pvs', '--version'],
	['pvs', '--separator :'],
	['pvs', '--separator : --segments'],
	['pvs', '-a --separator : --segments'],
	['pvs', '-av --separator : --segments'],
	['pvs', '-aPv --separator : --segments -o +pv_major,pv_minor'],
	['pvs', '-v --separator : --segments'],
	['pvs', '-Pv --separator : --segments'],
	['pvs', '--segments  -o pv_name,pv_size,seg_size,vg_name,lv_name,lv_size,seg_pe_ranges'],
	['readlink', '/dev/root'], # coreutils, don't need version
	['swapon', '-s'], # coreutils, don't need version
	# 3ware-raid
	['tw-cli', 'info'],
	['vgdisplay', ''],
	['vgdisplay', '-v'],
	['vgdisplay', '-c'],
	['vgdisplay', '-vc'],
	['vgs', '--separator :'], # part of lvm, don't need version
	['vgs', '-av --separator :'],
	['vgs', '-aPv --separator :'],
	['vgs', '-v --separator :'],
	['vgs', '-o +pv_name --separator :'],
	['zfs', 'list'],
	['zpool', 'list'], # don't use version, might not be supported in linux
	['zpool', 'list -v'],
	);
	run_commands(\@cmds,'disk');
	@cmds = (
	['atacontrol', 'list'],
	['camcontrol', 'devlist'], 
	['camcontrol', 'devlist -v'], 
	['geom', 'part list'],
	['glabel', 'status'], 
	['gpart', 'list'], # gpart in linux/bsd but do it here again
	['gpart', 'show'],
	['gpart', 'status'],
	['swapctl', '-l -k'],
	['swapctl', '-l -k'],
	['vmstat', ''],
	['vmstat', '-H'],
	);
	run_commands(\@cmds,'disk-bsd');
}

sub display_data {
	my (%data,@files,@files2);
	my $working = '';
	if (!$b_display){
		print "Warning: only some of the data collection can occur if you are not in X\n";
		main::toucher("$data_dir/display-data-warning-user-not-in-x");
	}
	if ($b_root){
		print "Warning: only some of the data collection can occur if you are running as Root user\n";
		main::toucher("$data_dir/display-data-warning-root-user");
	}
	print "Collecting Xorg log and xorg.conf files...\n";
	if (-d "/etc/X11/xorg.conf.d/"){
		@files = main::globber("/etc/X11/xorg.conf.d/*");
	}
	else {
		@files = ('/xorg-conf-d');
	}
	# keep this updated to handle all possible locations we know about for Xorg.0.log
	# not using $system_files{'xorg-log'} for now though it would be best to know what file is used
	main::set_xorg_log();
	push(@files, '/var/log/Xorg.0.log');
	push(@files, '/var/lib/gdm/.local/share/xorg/Xorg.0.log');
	push(@files, $ENV{'HOME'} . '/.local/share/xorg/Xorg.0.log');
	push(@files, $system_files{'xorg-log'}) if $system_files{'xorg-log'};
	push(@files, '/etc/X11/XFCconfig-4'); # very old format for xorg.conf
	push(@files, '/etc/X11/xorg.conf');
	copy_files(\@files,'display-xorg');
	print "Collecting X, xprop, glxinfo, xrandr, xdpyinfo data, Wayland info...\n";
	%data = (
	'desktop-session' => $ENV{'DESKTOP_SESSION'},
	'display' => $ENV{'DISPLAY'},
	'gdmsession' => $ENV{'GDMSESSION'},
	'gnome-desktop-session-id' => $ENV{'GNOME_DESKTOP_SESSION_ID'},
	'kde-full-session' => $ENV{'KDE_FULL_SESSION'},
	'kde-session-version' => $ENV{'KDE_SESSION_VERSION'},
	'vdpau-driver' => $ENV{'VDPAU_DRIVER'},
	'xdg-current-desktop' => $ENV{'XDG_CURRENT_DESKTOP'},
	'xdg-session-desktop' => $ENV{'XDG_SESSION_DESKTOP'},
	'xdg-vtnr' => $ENV{'XDG_VTNR'},
	# wayland data collectors:
	'wayland-display' =>  $ENV{'WAYLAND_DISPLAY'},
	'xdg-session-type' => $ENV{'XDG_SESSION_TYPE'},
	'gdk-backend' => $ENV{'GDK_BACKEND'},
	'qt-qpa-platform' => $ENV{'QT_QPA_PLATFORM'},
	'clutter-backend' => $ENV{'CLUTTER_BACKEND'},
	'sdl-videodriver' => $ENV{'SDL_VIDEODRIVER'},
	# program display values
	'size-cols-max' => $size{'max-cols'},
	'size-indent' => $size{'indent'},
	'size-lines-max' => $size{'max-lines'},
	'size-wrap-width' => $size{'max-wrap'},
	);
	write_data(\%data,'display');
	my @cmds = (
	# kde 5/plasma desktop 5, this is maybe an extra package and won't be used
	['about-distro',''],
	['aticonfig','--adapter=all --od-gettemperature'],
	['clinfo',''],
	['clinfo','--list'],
	['clinfo','--raw'], # machine friendly
	['eglinfo',''],
	['eglinfo','-B'],
	['es2_info',''],
	['glxinfo',''],
	['glxinfo','-B'],
	['kded','--version'],
	['kded1','--version'],
	['kded2','--version'],
	['kded3','--version'],
	['kded4','--version'],
	['kded5','--version'],
	['kded6','--version'],
	['kded7','--version'],
	['kf-config','--version'],
	['kf4-config','--version'],
	['kf5-config','--version'],
	['kf6-config','--version'],
	['kf7-config','--version'],
	['kwin_x11','--version'],
	# ['locate','/Xorg'], # for Xorg.wrap problem
	['loginctl','--no-pager list-sessions'],
	['ls','/sys/class/drm'],
	['nvidia-settings','-q screens'],
	['nvidia-settings','-c :0.0 -q all'],
	['nvidia-smi','-q'],
	['nvidia-smi','-q -x'],
	['plasmashell','--version'],
	['swaymsg','-t get_inputs -p'],
	['swaymsg','-t get_inputs -r'],
	['swaymsg','-t get_outputs -p'],
	['swaymsg','-t get_outputs -r'],
	['swaymsg','-t get_tree'],
	['swaymsg','-t get_workspaces -p'],
	['swaymsg','-t get_workspaces -r'],
	['vainfo',''],
	['vdpauinfo',''],
	['vulkaninfo',''],
	['vulkaninfo','--summary'],
	# ['vulkaninfo','--json'], # outputs to file, not sure how to output to stdout
	['wayland-info',''], # wayland-utils
	['weston-info',''], 
	['wmctrl','-m'],
	['weston','--version'],
	['wlr-randr',''],
	['xdpyinfo',''],
	['xdriinfo',''],
	['Xfbdev','-version'],
	['Xorg','-version'],
	['xprop','-root'],
	['xrandr',''],
	['xrandr','--prop'],
	['xrandr','--verbose'],
	['Xvesa','-version'],
	['Xvesa','-listmodes'],
	['Xwayland','-version'],
	);
	run_commands(\@cmds,'display');
}

sub network_data {
	print "Collecting networking data...\n";
	#	no warnings 'uninitialized';
	my @cmds = (
	['ifconfig',''], # no version maybe in bsd, --version in linux
	['ip','-Version'],
	['ip','addr'],
	['ip','-s link'],
	);
	run_commands(\@cmds,'network');
}

sub perl_modules {
	print "Collecting Perl module data (this can take a while)...\n";
	my @modules;
	my ($dirname,$holder,$mods,$value) = ('','','','');
	my $filename = 'perl-modules.txt';
	my @inc;
	foreach (sort @INC){
		# some BSD installs have '.' n @INC path
		if (-d $_ && $_ ne '.'){
			$_ =~ s/\/$//; # just in case, trim off trailing slash
			$value .= "EXISTS: $_\n";
			push(@inc, $_);
		} 
		else {
			$value .= "ABSENT: $_\n";
		}
	}
	main::writer("$data_dir/perl-inc-data.txt",$value);
	File::Find::find({ wanted => sub { 
		push(@modules, File::Spec->canonpath($_)) if /\.pm\z/  
	}, no_chdir => 1 }, @inc);
	@modules = sort @modules;
	foreach (@modules){
		my $dir = $_;
		$dir =~ s/[^\/]+$//;
		if (!$holder || $holder ne $dir){
			$holder = $dir;
			$value = "DIR: $dir\n";
			$_ =~ s/^$dir//;
			$value .= " $_\n";
		}
		else {
			$value = $_;
			$value =~ s/^$dir//;
			$value = " $value\n";
		}
		$mods .= $value;
	}
	open(my $fh, '>', "$data_dir/$filename");
	print $fh $mods;
	close $fh;
}

sub system_data {
	print "Collecting system data...\n";
	# has to run here because if null, error, list constructor throws fatal error
	my $ksh = qx(ksh -c 'printf \%s "\$KSH_VERSION"' 2>/dev/null);
	my %data = (
	'cc' => $ENV{'CC'},
	# @(#)MIRBSD KSH R56 2018/03/09: ksh and mksh
	'ksh-version' => $ksh, # shell, not env, variable
	'manpath' => $ENV{'MANPATH'},
	'path' => $ENV{'PATH'},
	'shell' => $ENV{'SHELL'},
	'xdg-config-home' => $ENV{'XDG_CONFIG_HOME'},
	'xdg-config-dirs' => $ENV{'XDG_CONFIG_DIRS'},
	'xdg-data-home' => $ENV{'XDG_DATA_HOME'},
	'xdg-data-dirs' => $ENV{'XDG_DATA_DIRS'},
	);
	my @files = main::globber('/usr/bin/gcc*');
	if (@files){
		$data{'gcc-versions'} = join("\n", @files);
	}
	else {
		$data{'gcc-versions'} = undef;
	}
	@files = main::globber('/sys/*');
	if (@files){
		$data{'sys-tree-ls-1-basic'} = join("\n", @files);
	}
	else {
		$data{'sys-tree-ls-1-basic'} = undef;
	}
	write_data(\%data,'system');
	# bsd tools http://cb.vu/unixtoolbox.xhtml
	my @cmds = (
	# general
	['sysctl', '-a'],
	['sysctl', '-b kern.geom.conftxt'],
	['sysctl', '-b kern.geom.confxml'],
	['usbdevs','-v'],
	# freebsd
	['ofwdump','-a'], # arm / soc
	['ofwdump','-ar'], # arm / soc
	['pciconf','-l -cv'],
	['pciconf','-vl'],
	['pciconf','-l'],
	['usbconfig','dump_device_desc'],
	['usbconfig','list'], # needs root, sigh... why?
	# openbsd
	['ofctl',''], # arm / soc, need to see data sample of this
	['pcidump',''],
	['pcidump','-v'],
	# netbsd
	['kldstat',''],
	['pcictl','pci0 list'],
	['pcictl','pci0 list -N'],
	['pcictl','pci0 list -n'],
	# sunos
	['prtdiag',''],
	['prtdiag','-v'],
	);
	run_commands(\@cmds,'system-bsd');
	# diskinfo -v <disk>
	# fdisk <disk>
	@cmds = (
	['clang','--version'],
	# only for prospective ram feature data collection: requires i2c-tools and module eeprom loaded
	['decode-dimms',''], 
	['dmidecode','--version'],
	['dmidecode',''],
	['dmesg',''],
	['fruid_print',''], # elbrus
	['gcc','--version'],
	['getconf','-a'],
	['getconf','-l'], # openbsd
	['initctl','list'],
	['ipmi-sensors','-V'], # version
	['ipmi-sensors',''],
	['ipmi-sensors','--output-sensor-thresholds'],
	['ipmitool','-V'],# version
	['ipmitool','sensor'],
	['lscpu',''],# part of util-linux
	['lsmem',''],
	['lsmem','--all'],
	['lspci','--version'],
	['lspci',''],
	['lspci','-k'],
	['lspci','-n'],
	['lspci','-nn'],
	['lspci','-nnk'],
	['lspci','-nnkv'],# returns ports
	['lspci','-nnv'],
	['lspci','-mm'],
	['lspci','-mmk'],
	['lspci','-mmkv'],
	['lspci','-mmv'],
	['lspci','-mmnn'],
	['lspci','-v'],
	['lsusb','--version'],
	['lsusb',''],
	['lsusb','-t'],
	['lsusb','-v'],
	['ps',''],
	['ps','aux'],
	['ps','auxww'],
	['ps','-e'],
	['ps','-p 1'],
	['runlevel',''],
	['rc-status','-a'],
	['rc-status','-l'],
	['rc-status','-r'],
	['sensors','--version'],
	['sensors',''],
	['sensors','-j'],
	['sensors','-u'],
	# leaving this commented out to remind that some systems do not
	# support strings --version, but will just simply hang at that command
	# which you can duplicate by simply typing: strings then hitting enter.
	# ['strings','--version'],
	['strings','present'],
	['sysctl','-a'],
	['systemctl','--version'],
	['systemctl','get-default'],
	['systemctl','list-units'],
	['systemctl','list-units --type=target'],
	['systemd-detect-virt',''],
	['tlp-stat',''], # no arg outputs all data
	['tlp-stat','-s'],
	['udevadm','info -e'],
	['udevadm','info -p /devices/virtual/dmi/id'],
	['udevadm','--version'],
	['uname','-a'],
	['upower','-e'],
	['uptime',''],
	['vcgencmd','get_mem arm'],
	['vcgencmd','get_mem gpu'],
	);
	run_commands(\@cmds,'system');
	my $glob = '/sys/devices/system/cpu/';
	$glob .= '{cpufreq,cpu*/topology,cpu*/cpufreq,cpu*/cache/index*,smt,';
	$glob .= 'vulnerabilities}/*';
	get_glob('sys','cpu',$glob);
	@files = main::globber('/dev/bus/usb/*/*');
	copy_files(\@files, 'system');
}

sub system_files {
	print "Collecting system files data...\n";
	my (%data,@files,@files2);
	@files = RepoItem::get($data_dir);
	copy_files(\@files, 'repo');
	# chdir "/etc";
	@files = main::globber('/etc/*[-_]{[rR]elease,[vV]ersion,issue}*');
	push(@files, '/etc/issue','
	/etc/lsb-release',
	'/etc/os-release',
	'/system/build.prop', # android data file, requires rooted
	'/var/log/installer/oem-id'); # ubuntu only for oem installs?
	copy_files(\@files,'system-distro');
	@files = main::globber('/etc/upstream[-_]{[rR]elease,[vV]ersion}/*');
	copy_files(\@files,'system-distro');
	@files = main::globber('/etc/calamares/branding/*/branding.desc');
	copy_files(\@files,'system-distro');
	@files = (
	'/etc/systemd/system/default.target',
	'/proc/1/comm',
	'/proc/bootdata', # elbrus
	'/proc/cmdline',
	'/proc/cpuinfo',
	'/proc/iomem',
	'/proc/meminfo',
	'/proc/modules',
	'/proc/net/arp',
	'/proc/version',
	);
	@files2=main::globber('/sys/class/power_supply/*/uevent');
	if (@files2){
		push(@files,@files2);
	}
	else {
		push(@files, '/sys-class-power-supply-empty');
	}
	copy_files(\@files, 'system');
	@files = (
	'/etc/make.conf',
	'/etc/src.conf',
	'/var/run/dmesg.boot',
	);
	copy_files(\@files,'system-bsd');
	@files = main::globber('/sys/devices/system/cpu/vulnerabilities/*');
	copy_files(\@files,'security');
}

## SELF EXECUTE FOR LOG/OUTPUT
sub run_self {
	print "Creating $self_name output file now. This can take a few seconds...\n";
	print "Starting $self_name from: $self_path\n";
	my $args = '-FERfJLrploudma --slots --pkg --edid';
	my $a = ($debugger{'arg'}) ? ' ' . $debugger{'arg'} : '';
	my $i = ($option eq 'main-full')? ' -i' : '';
	my $z = ($debugger{'filter'}) ? ' -z' : '';
	my $w = ($debugger{'width'}) ? $debugger{'width'} : 120;
	$args = $debugger{'arg-use'} if $debugger{'arg-use'};
	$args = "$args$a$i$z --debug 10 -y $w";
	my $arg_string = $args;
	$arg_string =~ s/\s//g; 
	my $self_file = "$data_dir/$self_name$arg_string.txt";
	my $cmd = "$self_path/$self_name $args > $self_file 2>&1";
	# print "Args: $args\nArg String: $arg_string\n";exit;
	system($cmd);
	copy($log_file, "$data_dir") or main::error_handler('copy-failed', "$log_file", "$!");
	system("$self_path/$self_name --recommends -y 120 > $data_dir/$self_name-recommends-120.txt 2>&1");
}

## UTILITIES COPY/CMD/WRITE
sub copy_files {
	my ($files_ref,$type,$alt_dir) = @_;
	my ($absent,$error,$good,$name,$unreadable);
	my $directory = ($alt_dir) ? $alt_dir : $data_dir;
	my $working = ($type ne 'proc') ? "$type-file-": '';
	foreach (@$files_ref){
		$name = $_;
		$name =~ s/^\///;
		$name =~ s/\//~/g;
		# print "$name\n" if $type eq 'proc';
		$name = "$directory/$working$name";
		$good = $name . '.txt';
		$absent = $name . '-absent';
		$error = $name . '-error';
		$unreadable = $name . '-unreadable';
		# proc have already been tested for readable/exists
		if ($type eq 'proc' || -e $_){
			print "F:$_\n" if $type eq 'proc' && $debugger{'proc-print'};
			if ($type eq 'proc' || -r $_){
				copy($_,"$good") or main::toucher($error);
			}
			else {
				main::toucher($unreadable);
			}
		}
		else {
			main::toucher($absent);
		}
	}
}

sub run_commands {
	my ($cmds,$type) = @_;
	my $holder = '';
	my ($name,$cmd,$args);
	foreach my $rows (@$cmds){
		if (my $program = main::check_program($rows->[0])){
			if ($rows->[1] eq 'present'){
				$name = "$data_dir/$type-cmd-$rows->[0]-present";
				main::toucher($name);
			}
			else {
				$args = $rows->[1];
				$args =~ s/\s|--|\/|=/-/g; # for:
				$args =~ s/--/-/g;# strip out -- that result from the above
				$args =~ s/^-//g;
				$args = "-$args" if $args;
				$name = "$data_dir/$type-cmd-$rows->[0]$args.txt";
				$cmd = "$program $rows->[1] >$name 2>&1";
				system($cmd);
			}
		}
		else {
			if ($holder ne $rows->[0]){
				$name = "$data_dir/$type-cmd-$rows->[0]-absent";
				main::toucher($name);
				$holder = $rows->[0];
			}
		}
	}
}

sub get_glob {
	my ($type,$id,$glob) = @_;
	my @files = main::globber($glob);
	return if !@files;
	my ($item,@result);
	foreach (sort @files){
		next if -d $_;
		if (-r $_) {
			$item = main::reader($_,'strip',0);
		}
		else {
			$item = main::message('root-required');
		}
		$item = main::message('undefined') if !defined $item;
		push(@result,$_ . '::' . $item);
	}
	# print Data::Dumper::Dumper \@result;
	main::writer("$data_dir/$type-data-$id-glob.txt",\@result);
}

sub write_data {
	my ($data_ref, $type) = @_;
	my ($empty,$error,$fh,$good,$name,$undefined,$value);
	foreach (keys %$data_ref){
		$value = $data_ref->{$_};
		$name = "$data_dir/$type-data-$_";
		$good = $name . '.txt';
		$empty = $name . '-empty';
		$error = $name . '-error';
		$undefined = $name . '-undefined';
		if (defined $value){
			if ($value || $value eq '0'){
				open($fh, '>', $good) or main::toucher($error);
				print $fh "$value";
			}
			else {
				main::toucher($empty);
			}
		}
		else {
			main::toucher($undefined);
		}
	}
}

## TOOLS FOR DIRECTORY TREE/LS/TRAVERSE; UPLOADER
sub build_tree {
	my ($which) = @_;
	if ($which eq 'sys' && main::check_program('tree')){
		print "Constructing /$which tree data...\n";
		my $dirname = '/sys';
		my $cmd;
		system("tree -a -L 10 /sys > $data_dir/sys-data-tree-full-10.txt");
		opendir(my $dh, $dirname) or main::error_handler('open-dir',"$dirname", "$!");
		my @files = readdir($dh);
		closedir $dh;
		foreach (@files){
			next if /^\./;
			$cmd = "tree -a -L 10 $dirname/$_ > $data_dir/sys-data-tree-$_-10.txt";
			# print "$cmd\n";
			system($cmd);
		}
	}
	print "Constructing /$which ls data...\n";
	if ($which eq 'sys'){
		directory_ls($which,1);
		directory_ls($which,2);
		directory_ls($which,3);
		directory_ls($which,4);
	}
	elsif ($which eq 'proc'){
		directory_ls('proc',1);
		directory_ls('proc',2,'[a-z]');
		# don't want the /proc/self or /proc/thread-self directories, those are 
		# too invasive
		#directory_ls('proc',3,'[a-z]');
		#directory_ls('proc',4,'[a-z]');
	}
}

# include is basic regex for ls path syntax, like [a-z]
sub directory_ls {
	my ($dir,$depth,$include) = @_;
	$include ||= '';
	my ($exclude) = ('');
	# we do NOT want to see anything in self or thread-self!!
	# $exclude = 'I self -I thread-self' if $dir eq 'proc';
	my $cmd = do {
		if ($depth == 1){ "ls -l $exclude /$dir/$include 2>/dev/null" }
		elsif ($depth == 2){ "ls -l $exclude /$dir/$include*/ 2>/dev/null" }
		elsif ($depth == 3){ "ls -l $exclude /$dir/$include*/*/ 2>/dev/null" }
		elsif ($depth == 4){ "ls -l $exclude /$dir/$include*/*/*/ 2>/dev/null" }
		elsif ($depth == 5){ "ls -l $exclude /$dir/$include*/*/*/*/ 2>/dev/null" }
		elsif ($depth == 6){ "ls -l $exclude /$dir/$include*/*/*/*/*/ 2>/dev/null" }
	};
	my @working;
	my $output = '';
	my ($type);
	my $result = qx($cmd);
	open(my $ch, '<', \$result) or main::error_handler('open-data',"$cmd", "$!");
	while (my $line = <$ch>){
		chomp($line);
		$line =~ s/^\s+|\s+$//g;
		@working = split(/\s+/, $line);
		$working[0] ||= '';
		if (scalar @working > 7){
			if ($working[0] =~ /^d/){
				$type = "d - ";
			}
			elsif ($working[0] =~ /^l/){
				$type = "l - ";
			}
			elsif ($working[0] =~ /^c/){
				$type = "c - ";
			}
			else {
				$type = "f - ";
			}
			$working[9] ||= '';
			$working[10] ||= '';
			$output = $output . "  $type$working[8] $working[9] $working[10]\n";
		}
		elsif ($working[0] !~ /^total/){
			$output = $output . $line . "\n";
		}
	}
	close $ch;
	my $file = "$data_dir/$dir-data-ls-$depth.txt";
	open(my $fh, '>', $file) or main::error_handler('create',"$file", "$!");
	print $fh $output;
	close $fh;
	# print "$output\n";
}

sub proc_traverse_data {
	print "Building /proc file list...\n";
	# get rid pointless error:Can't cd to (/sys/kernel/) debug: Permission denied
	#no warnings 'File::Find';
	no warnings;
	$parse_src = 'proc';
	File::Find::find(\&wanted, "/proc");
	process_proc_traverse();
	@content = ();
}

sub process_proc_traverse {
	my ($data,$fh,$result,$row,$sep);
	my $proc_dir = "$data_dir/proc";
	print "Adding /proc files...\n";
	mkdir $proc_dir or main::error_handler('mkdir', "$proc_dir", "$!");
	# @content = sort @content; 
	copy_files(\@content,'proc',$proc_dir);
	#	foreach (@content){print "$_\n";}
}

sub sys_traverse_data {
	print "Building /sys file list...\n";
	# get rid pointless error:Can't cd to (/sys/kernel/) debug: Permission denied
	#no warnings 'File::Find';
	no warnings;
	$parse_src = 'sys';
	File::Find::find(\&wanted, "/sys");
	process_sys_traverse();
	@content = ();
}

sub process_sys_traverse {
	my ($data,$fh,$result,$row,$sep);
	my $filename = "sys-data-parse.txt";
	print "Parsing /sys files...\n";
	# no sorts, we want the order it comes in
	# @content = sort @content; 
	foreach (@content){
		$data='';
		$sep='';
		my $b_fh = 1;
		print "F:$_\n" if $debugger{'sys-print'};
		open($fh, '<', $_) or $b_fh = 0;
		# needed for removing -T test and root
		if ($b_fh){
			while ($row = <$fh>){
				chomp($row);
				$data .= $sep . '"' . $row . '"';
				$sep=', ';
			}
		}
		else {
			$data = '<unreadable>';
		}
		$result .= "$_:[$data]\n";
		# print "$_:[$data]\n"
	}
	# print scalar @content . "\n";
	open($fh, '>', "$data_dir/$filename");
	print $fh $result;
	close $fh;
	# print $fh "$result";
}

# perl compiler complains on start if prune = 1 used only once, so either 
# do $File::Find::prune = 1 if !$File::Find::prune; OR use no warnings 'once'
sub wanted {
	# note: we want these directories pruned before the -d test so find 
	# doesn't try to read files inside of the directories
	if ($parse_src eq 'proc'){
		if ($File::Find::name =~ m!^/proc/[0-9]+! || 
		 # /proc/registry is from cygwin, we never want to see that
		 $File::Find::name =~ m!^/proc/(irq|spl|sys|reg)! ||
		 # these choke on sudo/root: kmsg kcore kpage and we don't want keys or kallsyms
		 $File::Find::name =~ m!^/proc/k! ||
		 $File::Find::name =~ m!^/proc/bus/pci!){
			$File::Find::prune = 1;
			return;
		}
	}
	elsif ($parse_src eq 'sys'){
		# note: a new file in 4.11 /sys can hang this, it is /parameter/ then
		# a few variables. Since inxi does not need to see that file, we will
		# not use it. 
		if ($File::Find::name =~ m!/(kernel/|trace/|parameters|debug)!){
			$File::Find::prune = 1;
		}
	}
	return if -d; # not directory
	return unless -e; # Must exist
	return unless -f; # Must be file
	return unless -r; # Must be readable
	if ($parse_src eq 'sys'){
		# print $File::Find::name . "\n";
		# block maybe: cfgroup\/
		# picdec\/|, wait_for_fb_sleep/wake is an odroid thing caused hang
		# wakeup_count also fails for android, but works fine on regular systems
		return if $risc{'arm'} && $File::Find::name =~ m!^/sys/power/(wait_for_fb_|wakeup_count$)!;
		# do not need . files or __ starting files
		return if $File::Find::name =~ m!/\.[a-z]!;
		# pp_num_states: amdgpu driver bug; android: wakeup_count
		return if $File::Find::name =~ m!/pp_num_states$!;
		# comment this one out if you experience hangs or if 
		# we discover syntax of foreign language characters
		# Must be ascii like. This is questionable and might require further
		# investigation, it is removing some characters that we might want
		# NOTE: this made a bunch of files on arm systems unreadable so we handle 
		# the readable tests in copy_files()
		# return unless -T; 
	}
	elsif ($parse_src eq 'proc'){
		return if $File::Find::name =~ m!(/mb_groups|debug)$!;
	}
	# print $File::Find::name . "\n";
	push(@content, $File::Find::name);
	return;
}

# args: 0: path to file to be uploaded; 1: optional: alternate ftp upload url
# NOTE: must be in format: ftp.site.com/incoming
sub upload_file {
	my ($self, $ftp_url) = @_;
	my ($ftp, $domain, $host, $user, $pass, $dir, $error);
	$ftp_url ||= main::get_defaults('ftp-upload');
	$ftp_url =~ s/\/$//g; # trim off trailing slash if present
	my @url = split('/', $ftp_url);
	my $file_path = "$user_data_dir/$debug_gz";
	$host = $url[0];
	$dir = $url[1];
	$domain = $host;
	$domain =~ s/^ftp\.//;
	$user = "anonymous";
	$pass = "anonymous\@$domain";
	print $line3;
	print "Uploading to: $ftp_url\n";
	# print "$host $domain $dir $user $pass\n";
	print "File to be uploaded:\n$file_path\n";
	if ($host && ($file_path && -e $file_path)){
		# NOTE: important: must explicitly set to passive true/1
		$ftp = Net::FTP->new($host, Debug => 0, Passive => 1) || main::error_handler('ftp-connect', $ftp->message);
		$ftp->login($user, $pass) || main::error_handler('ftp-login', $ftp->message);
		$ftp->binary();
		$ftp->cwd($dir);
		print "Connected to FTP server.\n";
		$ftp->put($file_path) || main::error_handler('ftp-upload', $ftp->message);
		$ftp->quit;
		print "Uploaded file successfully!\n";
		print $ftp->message;
		if ($debugger{'gz'}){
			print "Removing debugger gz file:\n$file_path\n";
			unlink $file_path or main::error_handler('remove',"$file_path", "$!");
			print "File removed.\n";
		}
		print "Debugger data generation and upload completed. Thank you for your help.\n";
	}
	else {
		main::error_handler('ftp-bad-path', "$file_path");
	}
}
}

# see docs/optimization.txt
sub ram_use {
    my ($name, $ref) = @_;
    printf "%-25s %5d %5d\n", $name, size($ref), total_size($ref);
}

# Used to create user visible debuugging output for complicated scenarios
# args: 0: $type; 1: data (scalar or array/hash ref); 2: 0/1 dbg item;
sub feature_debugger {
	my ($type,$data,$b_switch) = @_;
	my @result;
	push(@result,'sub: ' . (caller(1))[3],'type: ' . $type);
	if (ref $data eq 'ARRAY' || ref $data eq 'HASH'){
		$data = Data::Dumper::Dumper $data;
	}
	else {
		$data .= "\n" if !$b_log;
	}
	push(@result,'data: ' . $data);
	# note, if --debug 3 and eg. --dbg 63 used, we want this to print out
	if (!$b_log || ($b_switch && $debugger{'level'} < 10)){
		unshift(@result,'------------------');
		push(@result,"------------------\n") if $b_log;
		print join("\n",@result);
	}
	else {
		main::log_data('dump','feature dbg @result',\@result);
	}
}

# random tests for various issues
sub user_debug_test_1 {
# 	open(my $duped, '>&', STDOUT);
# 	local *STDOUT = $duped;
# 	my $item = POSIX::strftime("%c", localtime);
# 	print "Testing character encoding handling. Perl IO data:\n";
# 	print(join(', ', PerlIO::get_layers(STDOUT)), "\n");
# 	print "Without binmode: ", $item,"\n";
# 	binmode STDOUT,":utf8";
# 	print "With binmode: ", $item,"\n";
# 	print "Perl IO data:\n";
# 	print(join(', ', PerlIO::get_layers(STDOUT)), "\n");
# 	close $duped;
}

#### -------------------------------------------------------------------
#### DOWNLOADER
#### -------------------------------------------------------------------

# args: 0: download type; 1: url; 2: file; 3: [ua type string]
sub download_file {
	my ($type, $url, $file,$ua) = @_;
	my ($cmd,$args,$timeout) = ('','','');
	my $debug_data = '';
	my $result = 1;
	$ua = ($ua && $dl{'ua'}) ? $dl{'ua'} . $ua : '';
	$dl{'no-ssl'} ||= '';
	$dl{'spider'} ||= '';
	$file ||= 'N/A'; # to avoid debug error
	if (!$dl{'dl'}){
		return 0;
	}
	if ($dl{'timeout'}){
		$timeout = "$dl{'timeout'}$dl_timeout";
	}
	# print "$dl{'no-ssl'}\n";
	# print "$dl{'dl'}\n";
	# tiny supports spider sort of
	## NOTE: 1 is success, 0 false for Perl
	if ($dl{'dl'} eq 'tiny'){
		$cmd = "Using tiny: type: $type \nurl: $url \nfile: $file";
		$result = get_file_http_tiny($type,$url,$file,$ua);
		$debug_data = ($type ne 'stdout') ? $result : 'Success: stdout data not null.';
	}
	# But: 0 is success, and 1 is false for these
	# when strings are returned, they will be taken as true
	# urls must be " quoted in case special characters present
	else {
		if ($type eq 'stdout'){
			$args = $dl{'stdout'};
			$cmd = "$dl{'dl'} $dl{'no-ssl'} $ua $timeout $args \"$url\" $dl{'null'}";
			$result = qx($cmd);
			$debug_data = ($result) ? 'Success: stdout data not null.' : 'Download resulted in null data!';
		}
		elsif ($type eq 'file'){
			$args = $dl{'file'};
			$cmd = "$dl{'dl'} $dl{'no-ssl'} $ua $timeout $args $file \"$url\" $dl{'null'}";
			system($cmd);
			$result = ($?) ? 0 : 1; # reverse these into Perl t/f
			$debug_data = $result;
		}
		elsif ($dl{'dl'} eq 'wget' && $type eq 'spider'){
			$cmd = "$dl{'dl'} $dl{'no-ssl'} $ua $timeout $dl{'spider'} \"$url\"";
			system($cmd);
			$result = ($?) ? 0 : 1; # reverse these into Perl t/f
			$debug_data = $result;
		}
	}
	print "-------\nDownloader Data:\n$cmd\nResult: $debug_data\n" if $dbg[1];
	log_data('data',"$cmd\nResult: $result") if $b_log;
	return $result;
}

sub get_file_http_tiny {
	my ($type,$url,$file,$ua) = @_;
	$ua = ($ua && $dl{'ua'}) ? $dl{'ua'} . $ua:  '';
	my %headers = ($ua) ? ('agent' => $ua) : ();
	my $tiny = HTTP::Tiny->new(%headers);
	# note: default is no verify, so default here actually is to verify unless overridden
	$tiny->verify_SSL => 1 if !$use{'no-ssl'};
	my $response = $tiny->get($url);
	my $return = 1;
	my $debug = 0;
	my $fh;
	$file ||= 'N/A';
	log_data('dump','%{$response}',$response) if $b_log;
	# print Dumper $response;
	if (!$response->{'success'}){
		my $content = $response->{'content'};
		$content ||= "N/A\n";
		my $msg = "Failed to connect to server/file!\n";
		$msg .= "Response: ${content}Downloader: HTTP::Tiny URL: $url\nFile: $file";
		log_data('data',$msg) if $b_log;
		print error_defaults('download-error',$msg) if $dbg[1];
		$return = 0;
	}
	else {
		if ($debug){
			print "$response->{success}\n";
			print "$response->{status} $response->{reason}\n";
			while (my ($key, $value) = each %{$response->{'headers'}}){
				for (ref $value eq "ARRAY" ? @$value : $value){
					print "$key: $_\n";
				}
			}
		}
		if ($type eq "stdout" || $type eq "ua-stdout"){
			$return = $response->{'content'};
		}
		elsif ($type eq "spider"){
			# do nothing, just use the return value
		}
		elsif ($type eq "file"){
			open($fh, ">", $file);
			print $fh $response->{'content'}; # or die "can't write to file!\n";
			close $fh;
		}
	}
	return $return;
}

sub set_downloader {
	eval $start if $b_log;
	my $quiet = '';
	my $ua_raw = 's-tools/' . $self_name  . '-';
	$dl{'no-ssl'} = '';
	$dl{'null'} = '';
	$dl{'spider'} = '';
	# we only want to use HTTP::Tiny if it's present in user system.
	# It is NOT part of core modules. IO::Socket::SSL is also required 
	# For some https connections so only use tiny as option if both present
	if ($dl{'tiny'}){
		# this only for -U 4, grab file with ftp to avoid unsupported SSL issues
		if ($use{'ftp-download'}){
			$dl{'tiny'} = 0;
		}
		elsif (check_perl_module('HTTP::Tiny') && check_perl_module('IO::Socket::SSL')){
			HTTP::Tiny->import;
			IO::Socket::SSL->import;
			$dl{'tiny'} = 1;
		}
		else {
			$dl{'tiny'} = 0;
		}
	}
	# print $dl{'tiny'} . "\n";
	if ($dl{'tiny'}){
		$dl{'dl'} = 'tiny';
		$dl{'file'} = '';
		$dl{'stdout'} = '';
		$dl{'timeout'} = '';
		$dl{'ua'} = $ua_raw;
	}
	elsif ($dl{'curl'} && check_program('curl')){
		$quiet = '-s ' if !$dbg[1];
		$dl{'dl'} = 'curl';
		$dl{'file'} = "  -L ${quiet}-o ";
		$dl{'no-ssl'} = ' --insecure';
		$dl{'stdout'} = " -L ${quiet}";
		$dl{'timeout'} = ' -y ';
		$dl{'ua'} = ' -A ' . $ua_raw;
	}
	elsif ($dl{'wget'} && check_program('wget')){
		$quiet = '-q ' if !$dbg[1];
		$dl{'dl'} = 'wget';
		$dl{'file'} = " ${quiet}-O ";
		$dl{'no-ssl'} = ' --no-check-certificate';
		$dl{'spider'} = " ${quiet}--spider";
		$dl{'stdout'} = " $quiet -O -";
		$dl{'timeout'} = ' -T ';
		$dl{'ua'} = ' -U ' . $ua_raw;
	}
	elsif ($dl{'fetch'} && check_program('fetch')){
		$quiet = '-q ' if !$dbg[1];
		$dl{'dl'} = 'fetch';
		$dl{'file'} = " ${quiet}-o ";
		$dl{'no-ssl'} = ' --no-verify-peer';
		$dl{'stdout'} = " ${quiet}-o -";
		$dl{'timeout'} = ' -T ';
		$dl{'ua'} = ' --user-agent=' . $ua_raw;
	}
	# at least openbsd/netbsd
	elsif ($bsd_type && check_program('ftp')){
		$dl{'dl'} = 'ftp';
		$dl{'file'} = ' -o ';
		$dl{'null'} = ' 2>/dev/null';
		$dl{'stdout'} = ' -o - ';
		$dl{'timeout'} = '';
		$dl{'ua'} = ' -U ' . $ua_raw;
	}
	else {
		$dl{'dl'} = '';
	}
	# $use{'no-ssl' is set to 1 with --no-ssl, when false, unset to ''
	$dl{'no-ssl'} = '' if !$use{'no-ssl'};
	eval $end if $b_log;
}

sub set_perl_downloader {
	my ($downloader) = @_;
	$downloader =~ s/perl/tiny/;
	return $downloader;
}

#### -------------------------------------------------------------------
#### ERROR HANDLER
#### -------------------------------------------------------------------

sub error_handler {
	eval $start if $b_log;
	my ($err,$one,$two) = @_;
	my ($b_help,$b_recommends);
	my ($b_exit,$errno) = (1,0);
	my $message = do {
		if ($err eq 'empty'){ 'empty value' }
		## Basic rules
		elsif ($err eq 'not-in-irc'){ 
			$errno=1; "You can't run option $one in an IRC client!" }
		## Internal/external options
		elsif ($err eq 'bad-arg'){ 
			$errno=10; $b_help=1; "Unsupported value: $two for option: $one" }
		elsif ($err eq 'bad-arg-int'){ 
			$errno=11; "Bad internal argument: $one" }
		elsif ($err eq 'arg-modifier'){ 
			$errno=10; $b_help=1; "Missing option: $one must be used with: $two" }
		elsif ($err eq 'distro-block'){ 
			$errno=20; "Option: $one has been disabled by the $self_name distribution maintainer." }
		elsif ($err eq 'option-feature-incomplete'){ 
			$errno=21; "Option: '$one' feature: '$two' has not been implemented yet." }
		elsif ($err eq 'unknown-option'){ 
			$errno=22; $b_help=1; "Unsupported option: $one" }
		elsif ($err eq 'option-deprecated'){ 
			$errno=23; $b_exit=0; 
			"The option: $one has been deprecated. Please use $two instead." }
		elsif ($err eq 'option-removed'){ 
			$errno=24; $b_help=1; "The option: $one has been remnoved. Please use $two instead." }
		## Data
		elsif ($err eq 'open-data'){ 
			$errno=32; "Error opening data for reading: $one \nError: $two" }
		elsif ($err eq 'download-error'){ 
			$errno=33; "Error downloading file with $dl{'dl'}: $one \nError: $two" }
		## Files:
		elsif ($err eq 'copy-failed'){ 
			$errno=40; "Error copying file: $one \nError: $two" }
		elsif ($err eq 'create'){ 
			$errno=41; "Error creating file: $one \nError: $two" }
		elsif ($err eq 'downloader-error'){ 
			$errno=42; "Error downloading file: $one \nfor download source: $two" }
		elsif ($err eq 'file-corrupt'){ 
			$errno=43; "Downloaded file is corrupted: $one" }
		elsif ($err eq 'mkdir'){ 
			$errno=44; "Error creating directory: $one \nError: $two" }
		elsif ($err eq 'open'){ 
			$errno=45; $b_exit=0; "Error opening file: $one \nError: $two" }
		elsif ($err eq 'open-dir'){ 
			$errno=46; "Error opening directory: $one \nError: $two" }
		elsif ($err eq 'output-file-bad'){ 
			$errno=47; "Value for --output-file must be full path, a writable directory, \nand include file name. Path: $two" }
		elsif ($err eq 'not-writable'){ 
			$errno=48; "The file: $one is not writable!" }
		elsif ($err eq 'open-dir-failed'){ 
			$errno=49; "The directory: $one failed to open with error: $two" }
		elsif ($err eq 'remove'){ 
			$errno=50; "Failed to remove file: $one Error: $two" }
		elsif ($err eq 'rename'){ 
			$errno=51; "There was an error moving files: $one\nError: $two" }
		elsif ($err eq 'write'){ 
			$errno=52; "Failed writing file: $one - Error: $two!" }
		elsif ($err eq 'dir-missing'){ 
			$errno=53; "Directory supplied for option $one does not exist:\n $two" }
		## Downloaders
		elsif ($err eq 'missing-downloader'){ 
			$errno=60; "Downloader program $two could not be located on your system." }
		elsif ($err eq 'missing-perl-downloader'){ 
			$errno=61; $b_recommends=1; "Perl downloader missing required module." }
		## FTP
		elsif ($err eq 'ftp-bad-path'){ 
			$errno=70; "Unable to locate for FTP upload file:\n$one" }
		elsif ($err eq 'ftp-connect'){ 
			$errno=71; "There was an error with connection to ftp server: $one" }
		elsif ($err eq 'ftp-login'){ 
			$errno=72; "There was an error with login to ftp server: $one" }
		elsif ($err eq 'ftp-upload'){ 
			$errno=73; "There was an error with upload to ftp server: $one" }
		## Modules
		elsif ($err eq 'required-module'){ 
			$errno=80; $b_recommends=1; "The required $one Perl module is not installed:\n$two" }
		## Programs
		elsif ($err eq 'required-program'){ 
			$errno=90; "Required program '$one' could not be located on your system.\nNeeded for: $two" }
		## DEFAULT
		else {
			$errno=255; "Error handler ERROR!! Unsupported options: $err!"}
	};
	print_line("Error $errno: $message\n");
	if ($b_help){
		print_line("Check -h for correct useage.\n");
	}
	if ($b_recommends){
		print_line("See --recommends for more information.\n");
	}
	eval $end if $b_log;
	exit $errno if $b_exit && !$debugger{'no-exit'};
}

sub error_defaults {
	my ($type,$one) = @_;
	$one ||= '';
	my %errors = (
	'download-error' => "Download Failure:\n$one\n",
	);
	return $errors{$type};
}

#### -------------------------------------------------------------------
#### RECOMMENDS
#### -------------------------------------------------------------------

## CheckRecommends
{
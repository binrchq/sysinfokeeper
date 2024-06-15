package CheckRecommends;
my ($item_data,@modules,@pms);

sub run {
	main::error_handler('not-in-irc', 'recommends') if $b_irc;
	my (@data,@rows);
	my $rows = [];
	my $line = main::make_line();
	@pms = get_pms();
	set_item_data();
	basic_data($rows,$line);
	if (!$bsd_type){
		check_items($rows,'required system directories',$line);
	}
	check_items($rows,'recommended system programs',$line);
	check_items($rows,'recommended display information programs',$line);
	check_items($rows,'recommended downloader programs',$line);
	if (!$bsd_type){
		check_items($rows,'recommended kernel modules',$line);
	}
	check_items($rows,'recommended Perl modules',$line);
	check_items($rows,'recommended directories',$line);
	check_items($rows,'recommended files',$line);
	push(@$rows, 
	['0', '', '', "$line"],
	['0', '', '', "Ok, all done with the checks. Have a nice day."],
	['0', '', '', ''],
	);
	# print Data::Dumper::Dumper $rows;
	main::print_basic($rows); 
	exit 0; # shell true
}

sub basic_data {
	my ($rows,$line) = @_;
	my (@data,@rows);
	$extra = 1; # needed for shell version
	ShellData::set();
	my $client = $client{'name-print'};
	$client .= ' ' . $client{'version'} if $client{'version'};
	my $default_shell = 'N/A';
	if ($ENV{'SHELL'}){
		$default_shell = $ENV{'SHELL'};
		$default_shell =~ s/.*\///;
	}
	my $sh = main::check_program('sh');
	my $sh_real = Cwd::abs_path($sh);
	push(@$rows,
	['0', '', '', "$self_name will now begin checking for the programs it needs 
	to operate."],
	['0', '', '', ""],
	['0', '', '', "Check $self_name --help or the man page (man $self_name) 
	to see what options are available."],
	['0', '', '', "$line"],
	['0', '', '', "Test: core tools:"],
	['0', '', '', ""],
	['0', '', '', "Perl version: ^$]"],
	['0', '', '', "Current shell: " . $client],
	['0', '', '', "Default shell: " . $default_shell],
	['0', '', '', "sh links to: $sh_real"],
	);
	if (scalar @pms == 0){
		push(@$rows,['0', '', '', "Package manager(s): No supported PM(s) detected"]);
	}
	elsif (scalar @pms == 1){
		push(@$rows,['0', '', '', "Package manager: $pms[0]"]);
	}
	else {
		push(@$rows,['0', '', '', "Package managers detected:"]);
		foreach my $pm (@pms){
			push(@$rows,['0', '', '', " pm: $pm"]);
		}
	}
}

sub check_items {
	my ($rows,$type,$line) = @_;
	my (@data,@missing,$row,$result,@unreadable);
	my ($b_dir,$b_file,$b_kernel_module,$b_perl_module,$b_program,$item);
	my ($about,$extra,$extra2,$extra3,$extra4,$info_os) = ('','','','','','info');
	if ($type eq 'required system directories'){
		@data = qw(/proc /sys);
		$b_dir = 1;
		$item = 'Directory';
	}
	elsif ($type eq 'recommended system programs'){
		if ($bsd_type){
			@data = qw(camcontrol dig disklabel dmidecode doas fdisk file glabel gpart 
			ifconfig ipmi-sensors ipmitool pciconfig pcidump pcictl smartctl sudo 
			sysctl tree upower uptime usbconfig usbdevs);
			$info_os = 'info-bsd';
		}
		else {
			@data = qw(blockdev bt-adapter btmgmt dig dmidecode doas fdisk file 
			fruid_print hciconfig hddtemp ifconfig ip ipmitool ipmi-sensors lsblk 
			lsusb lvs mdadm modinfo runlevel sensors smartctl strings sudo tree 
			udevadm upower uptime);
		}
		$b_program = 1;
		$item = 'Program';
		$extra2 = "Note: IPMI sensors are generally only found on servers. To access 
		that data, you only need one of the ipmi items.";
	}
	elsif ($type eq 'recommended display information programs'){
		if ($bsd_type){
			@data = qw(eglinfo glxinfo vulkaninfo wayland-info wmctrl xdpyinfo xprop 
			xdriinfo xrandr);
			$info_os = 'info-bsd';
		}
		else {
			@data = qw(eglinfo glxinfo vulkaninfo wayland-info wmctrl xdpyinfo xprop 
			xdriinfo xrandr);
		}
		$b_program = 1;
		$item = 'Program';
	}
	elsif ($type eq 'recommended downloader programs'){
		if ($bsd_type){
			@data = qw(curl dig fetch ftp wget);
			$info_os = 'info-bsd';
		}
		else {
			@data = qw(curl dig wget);
		}
		$b_program = 1;
		$extra = ' (You only need one of these)';
		$extra2 = "Perl HTTP::Tiny is the default downloader tool if IO::Socket::SSL is present.
		See --help --alt 40-44 options for how to override default downloader(s) in case of issues. ";
		$extra3 = "If dig is installed, it is the default for WAN IP data. 
		Strongly recommended. Dig is fast and accurate.";
		$extra4 = ". However, you really only need dig in most cases. All systems should have ";
		$extra4 .= "at least one of the downloader options present.";
		$item = 'Program';
	}
	elsif ($type eq 'recommended Perl modules'){
		@data = qw(File::Copy File::Find File::Spec::Functions HTTP::Tiny IO::Socket::SSL 
		Time::HiRes JSON::PP Cpanel::JSON::XS JSON::XS XML::Dumper Net::FTP);
		if ($bsd_type && $bsd_type eq 'openbsd'){
			push(@data, qw(OpenBSD::Pledge OpenBSD::Unveil));
		}
		$b_perl_module = 1;
		$item = 'Perl Module';
		$extra = ' (Optional)';
		$extra2 = "None of these are strictly required, but if you have them all, 
		you can eliminate some recommended non Perl programs from the install. ";
		$extra3 = "HTTP::Tiny and IO::Socket::SSL must both be present to use as a 
		downloader option. For json export Cpanel::JSON::XS is preferred over 
		JSON::XS, but JSON::PP is in core modules. To run --debug 20-22 File::Copy,
		File::Find, and File::Spec::Functions must be present (most distros have 
		these in Core Modules).
		";
	}
	elsif ($type eq 'recommended kernel modules'){
		@data = qw(amdgpu drivetemp nouveau radeon);
		@modules = main::lister('/sys/module/');
		$b_kernel_module = 1;
		$extra2 = "GPU modules are only needed if applicable. NVMe drives do not need drivetemp 
		but other types do.";
		$extra3 = "To load a module: modprobe <module-name> - To  permanently load
		add to /etc/modules or /etc/modules-load.d/modules.conf (check your system
		paths for exact file/directory names).";
		$item = 'Kernel Module';
	}
	elsif ($type eq 'recommended directories'){
		if ($bsd_type){
			@data = qw(/dev);
		}
		else {
			@data = qw(/dev /dev/disk/by-id /dev/disk/by-label /dev/disk/by-path 
			/dev/disk/by-uuid /sys/class/dmi/id /sys/class/hwmon);
		}
		$b_dir = 1;
		$item = 'Directory';
	}
	elsif ($type eq 'recommended files'){
		if ($bsd_type){
			@data = qw(/var/run/dmesg.boot /var/log/Xorg.0.log);
		}
		else {
			@data = qw(/etc/lsb-release /etc/os-release /proc/asound/cards 
			/proc/asound/version /proc/cpuinfo /proc/mdstat /proc/meminfo /proc/modules 
			/proc/mounts /proc/scsi/scsi /var/log/Xorg.0.log);
		}
		$b_file = 1;
		$item = 'File';
		$extra2 = "Note that not all of these are used by every system, 
		so if one is missing it's usually not a big deal.";
	}
	push(@$rows,
	['0', '', '', "$line" ],
	['0', '', '', "Test: $type$extra:" ],
	['0', '', '', ''],
	);
	if ($extra2){
		push(@$rows, 
		['0', '', '', $extra2],
		['0', '', '', '']);
	}
	if ($extra3){
		push(@$rows, 
		['0', '', '', $extra3],
		['0', '', '', '']);
	}
	foreach my $item (@data){
		undef $about;
		my $info = $item_data->{$item};
		$about = $info->{$info_os};
		if (($b_dir && -d $item) || ($b_file && -r $item) ||
		($b_program && main::check_program($item)) || 
		($b_perl_module && main::check_perl_module($item)) ||
		($b_kernel_module && @modules && (grep {/^$item$/} @modules))){
			$result = 'Present';
		}
		elsif ($b_file && -f $item){
			$result = 'Unreadable';
			push(@unreadable, "$item");
		}
		else {
			$result = 'Missing';
			push(@missing,"$item");
			if (($b_program || $b_perl_module) && @pms){
				my @install;
				foreach my $pm (@pms){
					$info->{$pm} ||= 'N/A';
					push(@install," $pm: $info->{$pm}");
				}
				push(@missing,@install);
			}
		}
		$row = make_row($item,$about,$result);
		push(@$rows, ['0', '', '', $row]);
	}
	push(@$rows, ['0', '', '', '']);
	if (@missing){
		push(@$rows, ['0', '', '', "The following $type are missing$extra4:"]);
		foreach (@missing){
			push(@$rows, ['0', '', '', $_]);
		}
	}
	if (@unreadable){
		push(@$rows,  ['0', '', '', "The following $type are not readable: "]);
		foreach (@unreadable){
			push(@$rows, ['0', '', '', "$item: $_"]);
		}
	}
	if (!@missing && !@unreadable){
		push(@$rows, ['0', '', '', "All $type are present"]);
	}
}

sub set_item_data {
	$item_data = {
	## Directory Data ##
	'/dev' => {
	'info' => '-l,-u,-o,-p,-P,-D disk partition data',
	},
	'/dev/disk/by-id' => {
	'info' => '-D serial numbers',
	},
	'/dev/disk/by-path' => {
	'info' => '-D extra data',
	},
	'/dev/disk/by-label' => {
	'info' => '-l,-o,-p,-P partition labels',
	},
	'/dev/disk/by-uuid' => {
	'info' => '-u,-o,-p,-P partition uuid',
	},
	'/proc' => {
	'info' => '',
	},
	'/sys' => {
	'info' => '',
	},
	'/sys/class/dmi/id' => {
	'info' => '-M system, motherboard, bios',
	},
	'/sys/class/hwmon' => {
	'info' => '-s sensor data (fallback if no lm-sensors)',
	},
	## File Data ##
	'/etc/lsb-release' => {
	'info' => '-S distro version data (older version)',
	},
	'/etc/os-release' => {
	'info' => '-S distro version data (newer version)',
	},
	'/proc/asound/cards' => {
	'info' => '-A sound card data',
	},
	'/proc/asound/version' => {
	'info' => '-A ALSA data',
	},
	'/proc/cpuinfo' => {
	'info' => '-C cpu data',
	},
	'/proc/mdstat' => {
	'info' => '-R mdraid data (if you use dm-raid)',
	},
	'/proc/meminfo' => {
	'info' => '-I,-tm, -m memory data',
	},
	'/proc/modules' => {
	'info' => '-G module data (sometimes)',
	},
	'/proc/mounts' => {
	'info' => '-P,-p partition advanced data',
	},
	'/proc/scsi/scsi' => {
	'info' => '-D Advanced hard disk data (used rarely)',
	},
	'/var/log/Xorg.0.log' => {
	'info' => '-G graphics driver load status',
	},
	'/var/run/dmesg.boot' => {
	'info' => '-D,-d disk data',
	},
	## Kernel Module Data ##
	'amdgpu' => {
	'info' => '-s, -G AMD GPU sensor data (newer GPUs)',
	'info-bsd' => '',
	},
	'drivetemp' => {
	'info' => '-Dx drive temperature (kernel >= 5.6)',
	'info-bsd' => '',
	},
	'nouveau' => {
	'info' => '-s, -G Nvidia GPU sensor data (if using free driver)',
	'info-bsd' => '',
	},
	'radeon' => {
	'info' => '-s, -G AMD GPU sensor data (older GPUs)',
	'info-bsd' => '',
	},
	## START PACKAGE MANAGER BLOCK ##
	# BSD only tools do not list package manager install names
	## Programs-System ##
	# Note: see inxi-perl branch for details: docs/inxi-custom-recommends.txt
	# System Tools
	'blockdev' => {
	'info' => '--admin -p/-P (filesystem blocksize)',
	'info-bsd' => '',
	'apt' => 'util-linux',
	'pacman' => 'util-linux',
	'pkgtool' => 'util-linux',
	'rpm' => 'util-linux',
	},
	'bt-adapter' => {
	'info' => '-E bluetooth data (if no hciconfig, btmgmt)',
	'info-bsd' => '',
	'apt' => 'bluez-tools',
	'pacman' => 'bluez-tools',
	'pkgtool' => '', # needs to be built by user
	'rpm' => 'bluez-tools',
	},
	'btmgmt' => {
	'info' => '-E bluetooth data (if no hciconfig)',
	'info-bsd' => '',
	'apt' => 'bluez',
	'pacman' => 'bluez-utils',
	'pkgtool' => '', # needs to be built by user
	'rpm' => 'bluez',
	},
	'curl' => {
	'info' => '-i (if no dig); -w,-W; -U',
	'info-bsd' => '-i (if no dig); -w,-W; -U',
	'apt' => 'curl',
	'pacman' => 'curl',
	'pkgtool' => 'curl',
	'rpm' => 'curl',
	},
	'camcontrol' => {
	'info' => '',
	'info-bsd' => '-R; -D; -P. Get actual gptid /dev path',
	},
	'dig' => {
	'info' => '-i wlan IP',
	'info-bsd' => '-i wlan IP',
	'apt' => 'dnsutils',
	'pacman' => 'dnsutils',
	'pkgtool' => 'bind',
	'rpm' => 'bind-utils',
	},
	'disklabel' => {
	'info' => '',
	'info-bsd' => '-j, -p, -P; -R; -o (Open/NetBSD+derived)',
	},
	'dmidecode' => {
	'info' => '-M if no sys machine data; -m',
	'info-bsd' => '-M if null sysctl; -m; -B if null sysctl',
	'apt' => 'dmidecode',
	'pacman' => 'dmidecode',
	'pkgtool' => 'dmidecode',
	'rpm' => 'dmidecode',
	},
	'doas' => {
	'info' => '-Dx hddtemp-user; -o file-user (alt for sudo)',
	'info-bsd' => '-Dx hddtemp-user; -o file-user',
	'apt' => 'doas',
	'pacman' => 'doas',
	'pkgtool' => ' opendoas',
	'rpm' => 'doas',
	},
	'fdisk' => {
	'info' => '-D partition scheme (fallback)',
	'info-bsd' => '-D partition scheme',
	'apt' => 'fdisk',
	'pacman' => 'util-linux',
	'pkgtool' => 'util-linux',
	'rpm' => 'util-linux',
	},
	'fetch' => {
	'info' => '',
	'info-bsd' => '-i (if no dig); -w,-W; -U',
	},
	'file' => {
	'info' => '-o unmounted file system (if no lsblk)',
	'info-bsd' => '-o unmounted file system',
	'apt' => 'file',
	'pacman' => 'file',
	'pkgtool' => 'file',
	'rpm' => 'file',
	},
	'ftp' => {
	'info' => '',
	'info-bsd' => '-i (if no dig); -w,-W; -U',
	},
	'fruid_print' => {
	'info' => '-M machine data, Elbrus only',
	'info-bsd' => '',
	'apt' => '',
	'pacman' => '',
	'pkgtool' => '',
	'rpm' => '',
	},
	'glabel' => {
	'info' => '',
	'info-bsd' => '-R; -D; -P. Get actual gptid /dev path',
	},
	'gpart' => {
	'info' => '',
	'info-bsd' => '-p,-P; -R; -o (FreeBSD+derived)',
	},
	'hciconfig' => {
	'info' => '-E bluetooth data (deprecated, good report)',
	'info-bsd' => '',
	'apt' => 'bluez',
	'pacman' => 'bluez-utils-compat (frugalware: bluez-utils)',
	'pkgtool' => 'bluez',
	'rpm' => 'bluez-utils',
	},
	'hddtemp' => {
	'info' => '-Dx show hdd temp, if no drivetemp module',
	'info-bsd' => '-Dx show hdd temp',
	'apt' => 'hddtemp',
	'pacman' => 'hddtemp',
	'pkgtool' => 'hddtemp',
	'rpm' => 'hddtemp',
	},
	'ifconfig' => {
	'info' => '-i ip LAN (deprecated)',
	'info-bsd' => '-i ip LAN',
	'apt' => 'net-tools',
	'pacman' => 'net-tools',
	'pkgtool' => 'net-tools',
	'rpm' => 'net-tools',
	},
	'ip' => {
	'info' => '-i ip LAN',
	'info-bsd' => '',
	'apt' => 'iproute',
	'pacman' => 'iproute2',
	'pkgtool' => 'iproute2',
	'rpm' => 'iproute',
	},
	'ipmi-sensors' => {
	'info' => '-s IPMI sensors (servers)',
	'info-bsd' => '',
	'apt' => 'freeipmi-tools',
	'pacman' => 'freeipmi',
	'pkgtool' => 'freeipmi',
	'rpm' => 'freeipmi',
	},
	'ipmitool' => {
	'info' => '-s IPMI sensors (servers)',
	'info-bsd' => '-s IPMI sensors (servers)',
	'apt' => 'ipmitool',
	'pacman' => 'ipmitool',
	'pkgtool' => 'ipmitool',
	'rpm' => 'ipmitool',
	},
	'lsblk' => {
	'info' => '-L LUKS/bcache; -o unmounted file system (best option)',
	'info-bsd' => '-o unmounted file system',
	'apt' => 'util-linux',
	'pacman' => 'util-linux',
	'pkgtool' => 'util-linux',
	'rpm' => 'util-linux-ng',
	},
	'lvs' => {
	'info' => '-L LVM data',
	'info-bsd' => '',
	'apt' => 'lvm2',
	'pacman' => 'lvm2',
	'pkgtool' => 'lvm2',
	'rpm' => 'lvm2',
	},
	'lsusb' => {
	'info' => '-A usb audio; -J (optional); -N usb networking',
	'info-bsd' => '',
	'apt' => 'usbutils',
	'pacman' => 'usbutils',
	'pkgtool' => 'usbutils',
	'rpm' => 'usbutils',
	},
	'mdadm' => {
	'info' => '-Ra advanced mdraid data',
	'info-bsd' => '',
	'apt' => 'mdadm',
	'pacman' => 'mdadm',
	'pkgtool' => 'mdadm',
	'rpm' => 'mdadm',
	},
	'modinfo' => {
	'info' => 'Ax; -Nx module version',
	'info-bsd' => '',
	'apt' => 'module-init-tools',
	'pacman' => 'module-init-tools',
	'pkgtool' => 'kmod (earlier: module-init-tools)',
	'rpm' => 'module-init-tools',
	},
	'pciconfig' => {
	'info' => '',
	'info-bsd' => '-A,-E,-G,-N pci devices (FreeBSD+derived)',
	},
	'pcictl' => {
	'info' => '',
	'info-bsd' => '-A,-E,-G,-N pci devices (NetBSD+derived)',
	},
	'pcidump' => {
	'info' => '',
	'info-bsd' => '-A,-E,-G,-N pci devices (OpenBSD+derived, doas/su)',
	},
	'runlevel' => {
	'info' => '-I fallback to Perl',
	'info-bsd' => '',
	'apt' => 'systemd or sysvinit',
	'pacman' => 'systemd',
	'pkgtool' => 'sysvinit',
	'rpm' => 'systemd or sysvinit',
	},
	'sensors' => {
	'info' => '-s sensors output (optional, /sys supplies most)',
	'info-bsd' => '',
	'apt' => 'lm-sensors',
	'pacman' => 'lm-sensors',
	'pkgtool' => 'lm_sensors',
	'rpm' => 'lm-sensors',
	},
	'smartctl' => {
	'info' => '-Da advanced data',
	'info-bsd' => '-Da advanced data',
	'apt' => 'smartmontools',
	'pacman' => 'smartmontools',
	'pkgtool' => 'smartmontools',
	'rpm' => 'smartmontools',
	},
	'strings' => {
	'info' => '-I sysvinit version',
	'info-bsd' => '',
	'apt' => 'binutils',
	'pacman' => 'binutils',
	'pkgtool' => 'binutils',
	'rpm' => 'binutils',
	},
	'sudo' => {
	'info' => '-Dx hddtemp-user; -o file-user (try doas!)',
	'info-bsd' => '-Dx hddtemp-user; -o file-user (alt for doas)',
	'apt' => 'sudo',
	'pacman' => 'sudo',
	'pkgtool' => 'sudo',
	'rpm' => 'sudo',
	},
	'sysctl' => {
	'info' => '',
	'info-bsd' => '-C; -I; -m; -tm',
	},
	'tree' => {
	'info' => '--debugger 20,21 /sys tree',
	'info-bsd' => '--debugger 20,21 /sys tree',
	'apt' => 'tree',
	'pacman' => 'tree',
	'pkgtool' => 'tree',
	'rpm' => 'tree',
	},
	'udevadm' => {
	'info' => '-m ram data for non-root, or no dmidecode',
	'apt' => 'udev (non-systemd: eudev)',
	'pacman' => 'systemd',
	'pkgtool' => 'eudev',
	'rpm' => 'udev (fedora: systemd-udev)',
	},
	'upower' => {
	'info' => '-sx attached device battery info',
	'info-bsd' => '-sx attached device battery info',
	'apt' => 'upower',
	'pacman' => 'upower',
	'pkgtool' => 'upower',
	'rpm' => 'upower',
	},
	'uptime' => {
	'info' => '-I uptime',
	'info-bsd' => '-I uptime',
	'apt' => 'procps',
	'pacman' => 'procps',
	'pkgtool' => 'procps',
	'rpm' => 'procps',
	},
	'usbconfig' => {
	'info' => '',
	'info-bsd' => '-A; -E; -G; -J; -N; (FreeBSD+derived, doas/su)',
	},
	'usbdevs' => {
	'info' => '',
	'info-bsd' => '-A; -E; -G; -J; -N; (Open/NetBSD+derived)',
	},
	'wget' => {
	'info' => '-i (if no dig); -w,-W; -U',
	'info-bsd' => '-i (if no dig); -w,-W; -U',
	'apt' => 'wget',
	'pacman' => 'wget',
	'pkgtool' => 'wget',
	'rpm' => 'wget',
	},
	## Programs-Display ##
	'eglinfo' => {
	'info' => '-G X11/Wayland EGL info',
	'info-bsd' => '-G X11/Wayland EGL info',
	'apt' => 'mesa-utils (or: mesa-utils-extra)',
	'pacman' => 'mesa-utils',
	'pkgtool' => 'mesa',
	'rpm' => 'egl-utils (SUSE: Mesa-demo-egl)',
	},
	'glxinfo' => {
	'info' => '-G X11 GLX info',
	'info-bsd' => '-G X11 GLX info',
	'apt' => 'mesa-utils',
	'pacman' => 'mesa-utils',
	'pkgtool' => 'mesa',
	'rpm' => 'glx-utils (Fedora: glx-utils; SUSE: Mesa-demo-x)',
	},
	'vulkaninfo' => {
	'info' => '-G Vulkan API info',
	'info-bsd' => '-G Vulkan API info',
	'apt' => 'vulkan-tools',
	'pacman' => 'vulkan-tools',
	'pkgtool' => 'vulkan-tools',
	'rpm' => 'vulkan-demos (Fedora: vulkan-tools; SUSE: vulkan-demos)',
	},
	'wayland-info' => {
	'info' => '-G Wayland data (not for X)',
	'info-bsd' => '-G Wayland data (not for X)',
	'apt' => 'wayland-utils',
	'pacman' => 'wayland-utils',
	'pkgtool' => 'wayland-utils',
	'rpm' => 'wayland-utils',
	},
	'wmctrl' => {
	'info' => '-S active window manager (fallback)',
	'info-bsd' => '-S active window manager (fallback)',
	'apt' => 'wmctrl',
	'pacman' => 'wmctrl',
	'pkgtool' => 'wmctrl',
	'rpm' => 'wmctrl',
	},
	'xdpyinfo' => {
	'info' => '-G (X) Screen resolution, dpi; -Ga Screen size',
	'info-bsd' => '-G (X) Screen resolution, dpi; -Ga Screen size',
	'apt' => 'X11-utils',
	'pacman' => 'xorg-xdpyinfo',
	'pkgtool' => 'xdpyinfo',
	'rpm' => 'xorg-x11-utils (SUSE/Fedora: xdpyinfo)',
	},
	'xdriinfo' => {
	'info' => '-G (X) DRI driver (if missing, fallback to Xorg log)',
	'info-bsd' => '-G (X) DRI driver (if missing, fallback to Xorg log',
	'apt' => 'X11-utils',
	'pacman' => 'xorg-xdriinfo',
	'pkgtool' => 'xdriinfo',
	'rpm' => 'xorg-x11-utils (SUSE/Fedora: xdriinfo)',
	},
	'xprop' => {
	'info' => '-S (X) desktop data',
	'info-bsd' => '-S (X) desktop data',
	'apt' => 'X11-utils',
	'pacman' => 'xorg-xprop',
	'pkgtool' => 'xprop',
	'rpm' => 'x11-utils (Fedora/SUSE: xprop)',
	},
	'xrandr' => {
	'info' => '-G (X) monitors(s) resolution; -Ga monitor data',
	'info-bsd' => '-G (X) monitors(s) resolution; -Ga monitor data',
	'apt' => 'x11-xserver-utils',
	'pacman' => 'xrandr',
	'pkgtool' => 'xrandr',
	'rpm' => 'x11-server-utils (SUSE/Fedora: xrandr)',
	},
	## Perl Modules ##
	'Cpanel::JSON::XS' => {
	'info' => '-G wayland, --output json (faster).',
	'info-bsd' => '-G wayland, --output json (faster).',
	'apt' => 'libcpanel-json-xs-perl',
	'pacman' => 'perl-cpanel-json-xs',
	'pkgtool' => 'perl-Cpanel-JSON-XS',
	'rpm' => 'perl-Cpanel-JSON-XS',
	},
	'File::Copy' => {
	'info' => '--debug 20-22 - required for debugger.',
	'info-bsd' => '--debug 20-22 - required for debugger.',
	'apt' => 'Core Modules',
	'pacman' => 'Core Modules',
	'pkgtool' => 'Core Modules',
	'rpm' => 'perl-File-Copy',
	},
	'File::Find' => {
	'info' => '--debug 20-22 - required for debugger.',
	'info-bsd' => '--debug 20-22 - required for debugger.',
	'apt' => 'Core Modules',
	'pacman' => 'Core Modules',
	'pkgtool' => 'Core Modules',
	'rpm' => 'perl-File-Find',
	},
	'File::Spec::Functions' => {
	'info' => '--debug 20-22 - required for debugger.',
	'info-bsd' => '--debug 20-22 - required for debugger.',
	'apt' => 'Core Modules',
	'pacman' => 'Core Modules',
	'pkgtool' => 'Core Modules',
	'rpm' => 'Core Modules',
	},
	'HTTP::Tiny' => {
	'info' => '-U; -w,-W; -i (if dig not installed).',
	'info-bsd' => '-U; -w,-W; -i (if dig not installed)',
	'apt' => 'libhttp-tiny-perl (Core Modules >= 5.014)',
	'pacman' => 'Core Modules',
	'pkgtool' => 'perl-http-tiny (Core Modules >= 5.014)',
	'rpm' => 'Perl-http-tiny',
	},
	'IO::Socket::SSL' => {
	'info' => '-U; -w,-W; -i (if dig not installed).',
	'info-bsd' => '-U; -w,-W; -i (if dig not installed)',
	'apt' => 'libio-socket-ssl-perl',
	'pacman' => 'perl-io-socket-ssl',
	'pkgtool' => 'perl-IO-Socket-SSL', # maybe in core modules
	'rpm' => 'perl-IO-Socket-SSL',
	},
	'JSON::PP' => {
	'info' => '-G wayland, --output json (in CoreModules, slower).',
	'info-bsd' => '-G wayland, --output json (in CoreModules, slower).',
	'apt' => 'libjson-pp-perl (Core Modules >= 5.014)',
	'pacman' => 'perl-json-pp (Core Modules >= 5.014)',
	'pkgtool' => 'Core Modules >= 5.014',
	'rpm' => 'perl-JSON-PP',
	},
	'JSON::XS' => {
	'info' => '-G wayland, --output json (legacy).',
	'info-bsd' => '-G wayland, --output json (legacy).',
	'apt' => 'libjson-xs-perl',
	'pacman' => 'perl-json-xs',
	'pkgtool' => 'perl-JSON-XS',
	'rpm' => 'perl-JSON-XS',
	},
	'Net::FTP' => {
	'info' => '--debug 21,22',
	'info-bsd' => '--debug 21,22',
	'apt' => 'Core Modules',
	'pacman' => 'Core Modules',
	'pkgtool' => 'Core Modules',
	'rpm' => 'Core Modules',
	},
	'OpenBSD::Pledge' => {
	'info' => "$self_name Perl pledge support.",
	'info-bsd' => "$self_name Perl pledge support.",
	},
	'OpenBSD::Unveil' => {
	'info' => "Experimental: $self_name Perl unveil support.",
	'info-bsd' => "Experimental: $self_name Perl unveil support.",
	},
	'Time::HiRes' => {
	'info' => '-C cpu sleep (not required); --debug timers',
	'info-bsd' => '-C cpu sleep (not required); --debug timers',
	'apt' => 'Core Modules',
	'pacman' => 'Core Modules',
	'pkgtool' => 'Core Modules',
	'rpm' => 'perl-Time-HiRes',
	},
	'XML::Dumper' => {
	'info' => '--output xml - Crude and raw.',
	'info-bsd' => '--output xml - Crude and raw.',
	'apt' => 'libxml-dumper-perl',
	'pacman' => 'perl-xml-dumper',
	'pkgtool' => '', # package does not appear to exist
	'rpm' => 'perl-XML-Dumper',
	},
	## END PACKAGE MANAGER BLOCK ##
	};
}

sub get_pms {
	my @pms = ();
	# support maintainers of other pm types using custom lists
	if (main::check_program('dpkg')){
		push(@pms,'apt');
	}
	if (main::check_program('pacman')){
		push(@pms,'pacman');
	}
	# assuming netpkg uses installpkg as backend
	if (main::check_program('installpkg')){
		push(@pms,'pkgtool');
	}
	# rpm needs to go last because it's sometimes available on other pm systems
	if (main::check_program('rpm')){
		push(@pms,'rpm');
	}
	return @pms;
}

# note: end will vary, but should always be treated as longest value possible.
# expected values: Present/Missing
sub make_row {
	my ($start,$middle,$end) = @_;
	my ($dots,$line,$sep) = ('','',': ');
	foreach (0 .. ($size{'max-cols'} - 16 - length("$start$middle"))){
		$dots .= '.';
	}
	$line = "$start$sep$middle$dots $end";
	return $line;
}
}

#### -------------------------------------------------------------------
#### TOOLS
#### -------------------------------------------------------------------

# Duplicates the functionality of awk to allow for one liner
# type data parsing. note: -1 corresponds to awk NF
# args: 0: array of data; 1: search term; 2: field result; 3: separator
# correpsonds to: awk -F='separator' '/search/ {print $2}' <<< @data
# array is sent by reference so it must be dereferenced
# NOTE: if you just want the first row, pass it \S as search string
# NOTE: if $num is undefined, it will skip the second step
sub awk {
	eval $start if $b_log;
	my ($ref,$search,$num,$sep) = @_;
	my ($result);
	# print "search: $search\n";
	return if !@$ref || !$search;
	foreach (@$ref){
		next if !defined $_;
		if (/$search/i){
			$result = $_;
			$result =~ s/^\s+|\s+$//g;
			last;
		}
	}
	if ($result && defined $num){
		$sep ||= '\s+';
		$num-- if $num > 0; # retain the negative values as is
		$result = (split(/$sep/, $result))[$num];
		$result =~ s/^\s+|,|\s+$//g if $result;
	}
	eval $end if $b_log;
	return $result;
}

# 0: Perl module to check
sub check_perl_module {
	my ($module) = @_;
	my $b_present = 0;
	eval "require $module";
	$b_present = 1 if !$@;
	return $b_present;
}

# args: 0: string or path to search gneerated @paths data for.
# note: a few nano seconds are saved by using raw $_[0] for program
sub check_program {
	(grep { return "$_/$_[0]" if -e "$_/$_[0]"} @paths)[0];
}

sub cleanup {
	# maybe add in future: , $fh_c, $fh_j, $fh_x
	foreach my $fh ($fh_l){
		if ($fh){
			close $fh;
		}
	}
}

# args: 0,1: version numbers to compare by turning them to strings
# note that the structure of the two numbers is expected to be fairly 
# similar, otherwise it may not work perfectly.
sub compare_versions {
	my ($one,$two) = @_;
	if ($one && !$two){return $one;}
	elsif ($two && !$one){return $two;}
	elsif (!$one && !$two){return}
	my ($pad1,$pad2) = ('','');
	$pad1 = join('', map {$_ = sprintf("%04s", $_);$_ } split(/[._-]/, $one));
	$pad2 = join('', map {$_ = sprintf("%04s", $_);$_ } split(/[._-]/, $two));
	# print "p1:$pad1 p2:$pad2\n";
	if ($pad1 ge $pad2){return $one}
	elsif ($pad2 gt $pad1){return $two}
}

# some things randomly use hex with 0x starter, return always integer
# warning: perl will generate a 32 bit too big number warning if you pass it
# random values that exceed 2^32 in hex, even if the base system is 64 bit. 
# sample: convert_hex(0x000b0000000b);
sub convert_hex {
	return (defined $_[0] && $_[0] =~ /^0x/) ? hex($_[0]) : $_[0];
}

# returns count of files in directory, if 0, dir is empty
sub count_dir_files {
	return unless -d $_[0];
	opendir(my $dh, $_[0]) or error_handler('open-dir-failed', "$_[0]", $!); 
	my $count = grep { ! /^\.{1,2}/ } readdir($dh); # strips out . and ..
	closedir $dh;
	return $count;
}

# args: 0: the string to get piece of
# 1: the position in string, starting at 1 for 0 index.
# 2: the separator, default is ' '
sub get_piece {
	eval $start if $b_log;
	my ($string, $num, $sep) = @_;
	$num--;
	$sep ||= '\s+';
	$string =~ s/^\s+|\s+$//g;
	my @temp = split(/$sep/, $string);
	eval $end if $b_log;
	if (exists $temp[$num]){
		$temp[$num] =~ s/,//g;
		return $temp[$num];
	}
}

# args: 0: command to turn into an array; 1: optional: splitter;
# 2: strip-trim, clean data, remove empty lines
# similar to reader() except this creates an array of data 
# by lines from the command arg
sub grabber {
	eval $start if $b_log;
	my ($cmd,$split,$strip,$type) = @_;
	$type ||= 'arr';
	$split ||= "\n";
	my @rows;
	if ($strip){
		for (split(/$split/, qx($cmd))){
			next if /^\s*(#|$)/;
			$_ =~ s/^\s+|\s+$//g;
			push(@rows,$_);
		}
	}
	else {
		@rows = split(/$split/, qx($cmd));
	}
	eval $end if $b_log;
	return ($type eq 'arr') ? @rows : \@rows;
}

# args: 0: string value to glob
sub globber {
	eval $start if $b_log;
	my @files = <$_[0]>;
	eval $end if $b_log;
	return @files;
}

# arg MUST be quoted when inserted, otherwise perl takes it for a hex number
sub is_hex {
	return (defined $_[0] && $_[0] =~ /^0x/) ? 1 : 0;
}

## NOTE: for perl pre 5.012 length(undef) returns warning
# receives string, returns boolean 1 if integer
sub is_int {
	return 1 if (defined $_[0] && length($_[0]) && 
	 length($_[0]) == ($_[0] =~ tr/0123456789//));
}

# receives string, returns true/1 if >= 0 numeric. tr/// 4x faster than regex
sub is_numeric {
	return 1 if (defined $_[0] && ($_[0] =~ tr/0123456789//) >= 1 && 
	 length($_[0]) == ($_[0] =~ tr/0123456789.//) && ($_[0] =~ tr/.//) <= 1);
}

# gets array ref, which may be undefined, plus join string
# this helps avoid debugger print errors when we are printing arrays
# which we don't know are defined or not null.
# args: 0: array ref; 1: join string; 2: default value, optional
sub joiner {
	my ($arr,$join,$default) = @_;
	$default ||= '';
	my $string = '';
	foreach (@$arr){
		if (defined $_){
			$string .= $_ . $join;
		}
		else {
			$string .= $default . $join;
		}
	}
	return $string;
}

# gets directory file list
sub lister {
	return if ! -d $_[0];
	opendir my $dir, $_[0] or return;
	my @list = readdir $dir;
	@list = grep {!/^(\.|\.\.)$/} @list if @list;
	closedir $dir;
	return @list;
}
# checks for 1 of 3 perl json modules. All three have same encode_json, 
# decode_json() methods.
sub load_json {
	eval $start if $b_log;
	$loaded{'json'} = 1;
	# recommended, but not in core modules
	if (check_perl_module('Cpanel::JSON::XS')){
		Cpanel::JSON::XS->import(qw(encode_json decode_json));
		# my $new = Cpanel::JSON::XS->new;
		$use{'json'} = {'type' => 'cpanel-json-xs',
		'encode' => \&Cpanel::JSON::XS::encode_json,
		'decode' => \&Cpanel::JSON::XS::decode_json,};
		# $use{'json'} = {'type' => 'cpanel-json-xs',
		# 'new-json' => \Cpanel::JSON::XS->new()};
	}
	# somewhat legacy, not in perl modules
	elsif (check_perl_module('JSON::XS')){
		JSON::XS->import;
		$use{'json'} = {'type' => 'json-xs',
		'encode' => \&JSON::XS::encode_json,
		'decode' => \&JSON::XS::decode_json};
	}
	# perl, in core modules as of 5.14
	elsif (check_perl_module('JSON::PP')){
		JSON::PP->import;
		$use{'json'} = {'type' => 'json-pp',
		'encode' => \&JSON::PP::encode_json,
		'decode' => \&JSON::PP::decode_json};
	}
	eval $end if $b_log;
}

# args: 0: full file path, returns array of file lines;
# 1: optionsl, strip and clean data;
# 2: optional: undef|arr|ref|index return specific index, if it exists, else undef
# note: chomp has to chomp the entire action, not just <$fh>
sub reader {
	eval $start if $b_log;
	my ($file,$strip,$type) = @_;
	return if !$file || ! -r $file; # not all OS respect -r tests!!
	$type = 'arr' if !defined $type;
	my ($error,@rows);
	open(my $fh, '<', $file) or $error = $!; # $fh always non null, even on error
	if ($error){
		error_handler('open', $file, $error);
	}
	else {
		chomp(@rows = <$fh>);
		close $fh;
		if (@rows && $strip){
			my @temp;
			for (@rows){
				next if /^\s*(#|$)/;
				$_ =~ s/^\s+|\s+$//g;
				push(@temp,$_);
			}
			@rows = @temp;
		}
	}
	eval $end if $b_log;
	return @rows if $type eq 'arr';
	return \@rows if $type eq 'ref';
	# note: returns undef scalar value if $rows[index] does not exist
	return $rows[$type];
}

# args: 0: the file to create if not exists
sub toucher {
	my $file = shift;
	if (! -e $file){
		open(my $fh, '>', $file) or error_handler('create', $file, $!);
	}
}

# calling it trimmer to avoid conflicts with existing trim stuff
# args: 0: string to be right left trimmed. Also slices off \n so no chomp needed
# this thing is super fast, no need to log its times etc, 0.0001 seconds or less
sub trimmer {
	# eval $start if $b_log;
	my ($str) = @_;
	$str =~ s/^\s+|\s+$|\n$//g; 
	# eval $end if $b_log;
	return $str;
}

# args: 0: array, by ref, modifying by ref
# send array, assign to hash, changed array by reference, uniq values only.
sub uniq {
	my %seen;
	@{$_[0]} = grep !$seen{$_}++, @{$_[0]};
}

# args: 0: file full  path to write to; 1: array ref or scalar of data to write. 
# note: turning off strict refs so we can pass it a scalar or an array reference.
sub writer {
	my ($path, $content) = @_;
	my ($contents);
	no strict 'refs';
	# print Dumper $content, "\n";
	if (ref $content eq 'ARRAY'){
		$contents = join("\n", @$content); # or die "failed with error $!";
	}
	else {
		$contents = $content;
	}
	open(my $fh, ">", $path) or error_handler('open',"$path", "$!");
	print $fh $contents;
	close $fh;
}

#### -------------------------------------------------------------------
#### UPDATER
#### -------------------------------------------------------------------

# args: 0: type to return
sub get_defaults {
	my ($type) = @_;
	my %defaults = (
	'ftp-upload' => 'ftp.smxi.org/incoming',
	'inxi-branch-1' => 'https://codeberg.org/smxi/inxi/raw/one/',
	'inxi-branch-2' => 'https://codeberg.org/smxi/inxi/raw/two/',
	"$self_name-dev" => 'https://smxi.org/in/',
	"$self_name-dev-ftp" => 'ftp://ftp.smxi.org/outgoing/',
	"inxi-main" => 'https://codeberg.org/smxi/inxi/raw/master/',
	'pinxi-main' => 'https://codeberg.org/smxi/pinxi/raw/master/',
	);
	if ($defaults{$type}){
		return $defaults{$type};
	}
	else {
		error_handler('bad-arg-int', $type);
	}
}

# args: 0: download url, not including file name; 1: string to print out
# 2: update type option
# note that 0 must end in / to properly construct the url path
sub update_me {
	eval $start if $b_log;
	my ($self_download,$download_id) = @_;
	my $downloader_error=1;
	my $file_contents='';
	my $output = '';
	$self_path =~ s/\/$//; # dirname sometimes ends with /, sometimes not
	$self_download =~ s/\/$//; # dirname sometimes ends with /, sometimes not
	my $full_self_path = "$self_path/$self_name";
	if ($b_irc){
		error_handler('not-in-irc', "-U/--update")
	}
	if (! -w $full_self_path){
		error_handler('not-writable', "$self_name", '');
	}
	$output .= "Starting $self_name self updater.\n";
	$output .= "Using $dl{'dl'} as downloader.\n";
	$output .= "Currently running $self_name version number: $self_version\n";
	$output .= "Current version patch number: $self_patch\n";
	$output .= "Current version release date: $self_date\n";
	$output .= "Updating $self_name in $self_path using $download_id as download source...\n";
	print $output;
	$output = '';
	$self_download = "$self_download/$self_name";
	$file_contents = download_file('stdout', $self_download);
	# then do the actual download
	if ($file_contents){
		# make sure the whole file got downloaded and is in the variable
		print "Validating downloaded data...\n";
		if ($file_contents =~ /###\*\*EOF\*\*###/){
			open(my $fh, '>', $full_self_path);
			print $fh $file_contents or error_handler('write', $full_self_path, "$!");
			close $fh;
			qx(chmod +x '$self_path/$self_name');
			set_version_data();
			$output .= "Successfully updated to $download_id version: $self_version\n";
			$output .= "New $download_id version patch number: $self_patch\n";
			$output .= "New $download_id version release date: $self_date\n";
			$output .= "To run the new version, just start $self_name again.\n";
			$output .= "$line3\n";
			print $output;
			$output = '';
			if ($use{'man'}){
				update_man($self_download,$download_id);
			}
			else {
				print "Skipping man download because branch version is being used.\n";
			}
			exit 0;
		}
		else {
			error_handler('file-corrupt', "$self_name");
		}
	}
	# now run the error handlers on any downloader failure
	else {
		error_handler('download-error', $self_download, $download_id);
	}
	eval $end if $b_log;
}

sub update_man {
	eval $start if $b_log;
	my ($self_download,$download_id) = @_;
	my $man_file_location = set_man_location();
	my $man_file_path = "$man_file_location/$self_name.1" ;
	my ($file_contents,$man_file_url,$output,$program) = ('','','','');
	print "Starting download of man page file now.\n";
	if (! -d $man_file_location){
		print "The required man directory was not detected on your system.\n";
		print "Unable to continue: $man_file_location\n";
		return 0;
	}
	if (! -w $man_file_location){
		print "Cannot write to $man_file_location! Root privileges required.\n";
		print "Unable to continue: $man_file_location\n";
		return 0;
	}
	if (-f "/usr/share/man/man8/inxi.8.gz"){
		print "Updating man page location to man1.\n";
		rename "/usr/share/man/man8/inxi.8.gz", "$man_file_location/inxi.1.gz";
		if (check_program('mandb')){
			system('mandb');
		}
	}
	if (!($program = check_program('gzip'))){
		print "Required program gzip not found. Unable to install man page.\n";
		return 0;
	}
	# first choice is inxi.1/pinxi.1 from gh, second from smxi.org
	$man_file_url = $self_download . '.1';
	print "Updating $self_name.1 in $man_file_location\n";
	print "using $download_id branch as download source\n";
	print "Downloading man page file...\n";
	print "Download URL: $man_file_url\n" if $dbg[1];
	$file_contents = download_file('stdout', $man_file_url);
	if ($file_contents){
		# make sure the whole file got downloaded and is in the variable
		print "Download successful. Validating downloaded man file data...\n";
		if ($file_contents =~ m|\.\\" EOF|){
			print "Contents validated. Writing to man location...\n";
			open(my $fh, '>', $man_file_path);
			print $fh $file_contents or error_handler('write', $man_file_path, "$!");
			close $fh;
			print "Writing successful. Compressing file...\n";
			system("$program -9 -f $man_file_path > $man_file_path.gz");
			my $err = $?;
			if ($err > 0){
				print "Oh no! Something went wrong compressing the man file!\n";
				print "Error: $err\n";
			}
			else {
				print "Download, install, and compression of man page successful.\n";
				print "Check to make sure it works: man $self_name\n";
			}
		}
		else {
			error_handler('file-corrupt', "$self_name.1");
		}
	}
	# now run the error handlers on any downloader failure
	else {
		error_handler('download-error', $man_file_url, $download_id);
	}
	eval $end if $b_log;
}

sub set_man_location {
	my $location='';
	my $default_location='/usr/share/man/man1';
	my $man_paths=qx(man --path 2>/dev/null);
	my $man_local='/usr/local/share/man';
	my $b_use_local=0;
	if ($man_paths && $man_paths =~ /$man_local/){
		$b_use_local=1;
	}
	# for distro installs
	if (-f "$default_location/inxi.1.gz"){
		$location=$default_location;
	}
	else {
		if ($b_use_local){
			if (! -d "$man_local/man1"){
				mkdir "$man_local/man1";
			}
			$location="$man_local/man1";
		}
	}
	if (!$location){
		$location=$default_location;
	}
	return $location;
}

# update for updater output version info
# note, this is only now used for self updater function so it can get
# the values from the UPDATED file, NOT the running program!
sub set_version_data {
	open(my $fh, '<', "$self_path/$self_name");
	while (my $row = <$fh>){
		chomp($row);
		$row =~ s/'|;//g;
		if ($row =~ /^my \$self_name/){
			$self_name = (split('=', $row))[1];
		}
		elsif ($row =~ /^my \$self_version/){
			$self_version = (split('=', $row))[1];
		}
		elsif ($row =~ /^my \$self_date/){
			$self_date = (split('=', $row))[1];
		}
		elsif ($row =~ /^my \$self_patch/){
			$self_patch = (split('=', $row))[1];
		}
		elsif ($row =~ /^## END INXI INFO/){
			last;
		}
	}
	close $fh;
}

########################################################################
#### OPTIONS HANDLER / VERSION
########################################################################

## OptionsHandler
{
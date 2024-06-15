package DistroData;
my ($id_src,@osr,@working);
my ($etc_issue,$lc_issue,$os_release) = ('','','/etc/os-release');
my $distro = {
'base' => '',
'base-files' => [], 
'base-method' => [],
'file' => '',
'files' => [],
'id' => '',
'method' => [],
'name' => '',
};

sub get {
	eval $start if $b_log;
	if ($dbg[66] || $b_log){
		$distro->{'dbg'} = 1;
	}
	if ($bsd_type){
		get_distro_bsd();
	}
	else {
		get_distro_linux();
	}
	eval $end if $b_log;
	return $distro;
}

## BSD ##
sub get_distro_bsd {
	eval $start if $b_log;
	# used to parse /System/Library/CoreServices/SystemVersion.plist for Darwin
	# but dumping that since it broke, just using standard BSD uname 0 2 name.
	if (!$distro->{'name'}){
		my $bsd_type_osr = 'dragonfly';
		if (-r $os_release){
			@osr = main::reader($os_release);
			push(@{$distro->{'files'}},$os_release) if $distro->{'dbg'};
			if (@osr && $bsd_type =~ /($bsd_type_osr)/ && (grep {/($bsd_type_osr)/i} @osr)){
				$distro->{'name'} = get_osr();
				$distro->{'id'} = lc($1);
				push(@{$distro->{'method'}},$os_release);
			}
		}
	}
	if (!$distro->{'name'}){
		my $bsd_type_version = 'truenas';
		my ($version_file,$version_info) = ('/etc/version','');
		if (-r $version_file){
			$version_info = main::reader($version_file,'strip');
			push(@{$distro->{'files'}},$version_file) if $distro->{'dbg'};
			if ($version_info && $version_info =~ /($bsd_type_version)/i){
				$distro->{'name'} = $version_info;
				$distro->{'id'} = lc($1);
				push(@{$distro->{'method'}},$version_file);
			}
		}
	}	
	if (!$distro->{'name'}){
		# seen a case without osx file, or was it permissions?
		# this covers all the other bsds anyway, no problem.
		$distro->{'name'} = "$uname[0] $uname[2]";
		$distro->{'id'} = lc($uname[0]);
		push(@{$distro->{'method'}},'uname 0, 2');
	}
	if ($distro->{'name'} &&
	(-e '/etc/pkg/GhostBSD.conf' || -e '/usr/local/etc/pkg/repos/GhostBSD.conf') && 
	$distro->{'name'} =~ /freebsd/i){
		my $version = (main::grabber("pkg query '%v' os-generic-userland-base 2>/dev/null"))[0];
		# only swap if we get result from the query
		if ($version){
			$distro->{'base'} = $distro->{'name'};
			$distro->{'name'} = "GhostBSD $version";
			push(@{$distro->{'method'}},'pkg query');
		}
	}
	if ($distro->{'dbg'}){
		dbg_distro_files('BSD',$distro->{'files'});
		main::feature_debugger('name: $distro: pre-base [bsd]',$distro);
	}
	system_base_bsd() if $extra > 0;
	eval $end if $b_log;
}

sub system_base_bsd {
	eval $start if $b_log;
	# ghostbsd is handled in main bsd section
	if (lc($uname[1]) eq 'nomadbsd' && $distro->{'id'} eq 'freebsd'){
		$distro->{'base'} = $distro->{'name'};
		$distro->{'name'} = $uname[1];
		push(@{$distro->{'method-base'}},'uname 1');
	}
	elsif (-f '/etc/pkg/HardenedBSD.conf' && $distro->{'id'} eq 'freebsd'){
		$distro->{'base'} = $distro->{'name'};
		$distro->{'name'} = 'HardenedBSD';
		push(@{$distro->{'method-base'}},'/etc/pkg/HardenedBSD.conf');
	}
	elsif ($distro->{'id'} =~ /^(truenas)$/){
		$distro->{'base'} = "$uname[0] $uname[2]";
		push(@{$distro->{'method-base'}},'uname 0 + 2');
	}
	main::feature_debugger('system-base: $distro [bsd]',$distro) if $distro->{'dbg'};
	eval $end if $b_log;
}

# GNU/LINUX ##
sub get_distro_linux {
	# NOTE: increasingly no distro release files are present, so this logic is 
	# deprecated, but still works often.
	# order matters!
	my @derived = qw(antix-version aptosid-version bodhibuilder.conf kanotix-version 
	knoppix-version pclinuxos-release mandrake-release manjaro-release mx-version 
	pardus-release porteus-version q4os_version sabayon-release 
	siduction-version sidux-version slax-version slint-version slitaz-release 
	solusos-release turbolinux-release zenwalk-version);
	my $derived_str = join('|', @derived);
	my @primary = qw(altlinux-release arch-release gentoo-release redhat-release 
	slackware-version SuSE-release);
	my $primary_str = join('|', @primary);
	my $exclude_str = 'debian_version|devuan_version|ubuntu_version';
	# note, pclinuxos has all these mandrake/mandriva files, careful!
	my $lsb_good_str = 'mandrake-release|mandriva-release|mandrakelinux-release|';
	$lsb_good_str .= 'manjaro-release';
	my $osr_good_str = 'altlinux-release|arch-release|mageia-release|';
	$osr_good_str .= 'pclinuxos-release|rpi-issue|SuSE-release';
	# We need these empirically verified one by one as they appear, but always remember
	# that stuff changes, legacy, deprecated, but these ideally are going to be right
	my $osr_good = 'antergos|chakra|fedora|guix|mageia|manjaro|oracle|pclinuxos|';
	$osr_good .= 'porteux|raspberry pi os|slint|zorin';
	# Force use of pretty name because that's only location of derived distro name
	# devuan should catch many devuans spins, which often put their names in pretty
	my $osr_pretty = 'devuan|slackel|zinc';
	my $dist_file_no_name = 'slitaz'; # these may not have the distro name in the file
	my ($issue,$lsb_release) = ('/etc/issue','/etc/lsb-release');
	# Note: OpenSuse Tumbleweed 2018-05 has made /etc/issue created by sym link to /run/issue
	# and then made that resulting file 700 permissions, which is obviously a mistake
	$etc_issue = main::reader($issue,'strip',0) if -r $issue;
	# debian issue can end with weird escapes like \n \l 
	# antergos: Antergos Linux \r (\l)
	$etc_issue = main::clean_characters($etc_issue) if $etc_issue;
	# Note: always exceptions, so wild card after release/version: 
	# /etc/lsb-release-crunchbang
	# Wait to handle since crunchbang file is one of the few in the world that 
	# uses this method
	@{$distro->{'files'}} = main::globber('/etc/{*[-_]{[rR]elease,[vV]ersion}*,issue}');
	push(@{$distro->{'files'}}, '/etc/bodhibuilder.conf') if -r '/etc/bodhibuilder.conf'; # legacy
	@osr = main::reader($os_release) if -r $os_release;
	if (-f '/etc/bodhi/info'){
		$lsb_release = '/etc/bodhi/info';
		$distro->{'file'} = $lsb_release;
		$distro->{'issue-skip'} = 1;
		push(@{$distro->{'files'}}, $lsb_release);
	}
	$distro->{'issue'} = $issue if -f $issue;
	$distro->{'lsb'} = $lsb_release if -f $lsb_release;
	if (!$distro->{'issue-skip'} && $etc_issue){
		$lc_issue = lc($etc_issue);
		if ($lc_issue =~ /(antergos|grml|linux lite|openmediavault)/){
			$distro->{'id'} = $1;
			$distro->{'issue-skip'} = 1;
		}
		# This raspbian detection fails for raspberry pi os
		elsif ($lc_issue =~ /(raspbian|peppermint)/){
			$distro->{'id'} = $1;
			$distro->{'file'} = $os_release if @osr;
		}
		# Note: wrong fix, applies to both raspbian and raspberry pi os
		# assumption here is that r pi os fixes this before stable release
		elsif ($lc_issue =~ /^debian/ && -e '/etc/apt/sources.list.d/raspi.list' && 
		(grep {/[^#]+raspberrypi\.org/} main::reader('/etc/apt/sources.list.d/raspi.list'))){
			$distro->{'id'} = 'raspios' ;
		}
	}
	# Note that antergos changed this around 	# 2018-05, and now lists 
	# antergos in os-release, sigh... We want these distros to use os-release 
	# if it contains their names. Last check below
	if (@osr){
		if (grep {/($osr_good)/i} @osr){
			$distro->{'file'} = $os_release;
		}
		elsif (grep {/($osr_pretty)/i} @osr){
			$distro->{'osr-pretty'} = 1;
			$distro->{'file'} = $os_release;
		}
	}
	if (grep {/armbian/} @{$distro->{'files'}}){
		$distro->{'id'} = 'armbian' ;
	}
	$distro->{'file-for-0'} = $distro->{'file'};
	dbg_distro_files('Linux',$distro->{'files'}) if $distro->{'dbg'};
	if (!$distro->{'file'}){
		if (scalar @{$distro->{'files'}} == 1){
			$distro->{'file'} = $distro->{'files'}[0];
		}
		elsif (scalar @{$distro->{'files'}} > 1){
			# Special case, to force manjaro/antergos which also have arch-release
			# manjaro should use lsb, which has the full info, arch uses os release
			# antergos should use /etc/issue. We've already checked os-release above
			if ($distro->{'id'} eq 'antergos' || (grep {/antergos|chakra|manjaro/} @{$distro->{'files'}})){
				@{$distro->{'files'}} = grep {!/arch-release/} @{$distro->{'files'}};
			}
			my $dist_files_str = join('|', @{$distro->{'files'}});
			foreach my $file ((@derived,@primary)){
				if ("/etc/$file" =~ /($dist_files_str)$/){
					# These is for only those distro's with self named release/version files
					# because Mint does not use such, it must be done as below 
					# Force use of os-release file in cases where there might be conflict 
					# between lsb-release rules and os-release priorities.
					if (@osr && $file =~ /($osr_good_str)$/){
						$distro->{'file'} = $os_release;
					}
					# Now lets see if the distro file is in the known-good working-lsb-list
					# if so, use lsb-release, if not, then just use the found file
					elsif ($distro->{'lsb'} && $file =~ /$lsb_good_str/){
						$distro->{'file'} = $lsb_release;
					}
					else {
						$distro->{'file'} = "/etc/$file";
					}
					last;
				}
			}
		}
	}
	$distro->{'file-for-1'} = $distro->{'file'};
	# first test for the legacy antiX distro id file
	if (-r '/etc/antiX'){
		@working = main::reader('/etc/antiX');
		$distro->{'name'} = main::awk(\@working,'antix.*\.iso') if @working;
		$distro->{'name'} = main::clean_characters($distro->{'name'}) if $distro->{'name'};
		push(@{$distro->{'method'}},'file: /etc/antiX');
	}
	# This handles case where only one release/version file was found, and it's lsb-release. 
	# This would never apply for ubuntu or debian, which will filter down to the following 
	# conditions. In general if there's a specific distro release file available, that's to 
	# be preferred, but this is a good backup.
	elsif ($distro->{'file'} && $distro->{'lsb'} && 
	($distro->{'file'} =~ /\/etc\/($lsb_good_str)$/ || $distro->{'file'} eq $lsb_release)){
		# print "df: $distro->{'file'} lf: $lsb_release\n";
		$distro->{'name'} = get_lsb($lsb_release);
		push(@{$distro->{'method'}},'get_lsb(): primary');
	}
	elsif ($distro->{'file'} && $distro->{'file'} eq $os_release){
		$distro->{'name'} = get_osr();
		$distro->{'osr-skip'} = 1;
		push(@{$distro->{'method'}},'get_osr(): primary');
	}
	# If distro id file was found and it's not in the exluded primary distro file list, read it
	elsif ($distro->{'file'} && -s $distro->{'file'} && $distro->{'file'} !~ /\/etc\/($exclude_str)$/){
		# New opensuse uses os-release, but older ones may have a similar syntax, so just use 
		# the first line
		if ($distro->{'file'} eq '/etc/SuSE-release'){
			# Leaving off extra data since all new suse have it, in os-release, this file has 
			# line breaks, like os-release  but in case we  want it, it's: 
			# CODENAME = Mantis  | VERSION = 12.2 
			# For now, just take first occurrence, which should be the first line, which does 
			# not use a variable type format
			@working = main::reader($distro->{'file'});
			$distro->{'name'} = main::awk(\@working,'suse');
			push(@{$distro->{'method'}}, 'custom: suse-release');
		}
		elsif ($distro->{'file'} eq '/etc/bodhibuilder.conf'){
			@working = main::reader($distro->{'file'});
			$distro->{'name'} = main::awk(\@working,'^LIVECDLABEL',2,'\s*=\s*');
			$distro->{'name'} =~ s/"//g if $distro->{'name'};
			push(@{$distro->{'method'}},'custom: /etc/bodhibuilder');
		}
		else {
			$distro->{'name'} = main::reader($distro->{'file'},'',0);
			# only contains version number. Why? who knows.
			if ($distro->{'file'} eq '/etc/q4os_version' && $distro->{'name'} !~ /q4os/i){
				$distro->{'name'} = "Q4OS $distro->{'name'}" ;
			}
			push(@{$distro->{'method'}},'default: distro file');
		}
		if ($distro->{'name'}){
			$distro->{'name'} = main::clean_characters($distro->{'name'});
		}
	}
	# Otherwise try  the default debian/ubuntu/distro /etc/issue file
	elsif ($distro->{'issue'}){
		if (!$distro->{'id'} && $lc_issue && $lc_issue =~ /(mint|lmde)/){
			$distro->{'id'} = $1;
			$distro->{'issue-skip'} = 1;
		}
		# os-release/lsb gives more manageable and accurate output than issue, 
		# but mint should use issue for now. Antergos uses arch os-release, but issue shows them
		if (!$distro->{'issue-skip'} && @osr){
			$distro->{'name'} = get_osr();
			$distro->{'osr-skip'} = 1;
			push(@{$distro->{'method'}},'get_osr(): w/issue');
		}
		elsif (!$distro->{'issue-skip'} && $distro->{'lsb'}){
			$distro->{'name'} = get_lsb();
			push(@{$distro->{'method'}},'get_lsb(): w/issue');
		}
		elsif ($etc_issue){
			if (-d '/etc/guix' && $lc_issue =~ /^this is the gnu system\./){
				# No standard paths or files for os data, use pm version
				($distro->{'name'},my $version) = ProgramData::full('guix');
				$distro->{'name'} .= " $version" if $version;
				$distro->{'issue-skip'} = 1;
				push(@{$distro->{'method'}},'issue-id; from program version');
			}
			else {
				$distro->{'name'} =  $etc_issue;
				push(@{$distro->{'method'}},'issue: source');
				# This handles an arch bug where /etc/arch-release is empty and /etc/issue 
				# is corrupted only older arch installs that have not been updated should 
				# have this fallback required, new ones use os-release
				if ($distro->{'name'} =~ /arch linux/i){
					$distro->{'name'} = 'Arch Linux';
				}
			}
		}
	}
	# A final check. If a long value, before assigning the debugger output, if os-release
	# exists then let's use that if it wasn't tried already. Maybe that will be better.
	# not handling the corrupt data, maybe later if needed. 10 + distro: (8) + string
	if ($distro->{'name'} && length($distro->{'name'}) > 60){
		if (!$distro->{'osr-skip'} && @osr){
			$distro->{'name'} = get_osr();
			$distro->{'osr-skip'} = 1;
			push(@{$distro->{'method'}},'get_osr(): bad name');
		}
	}
	# Test for /etc/lsb-release as a backup in case of failure, in cases 
	# where > one version/release file were found but the above resulted 
	# in null distro value. 
	if (!$distro->{'name'} && $windows{'cygwin'}){
		$distro->{'name'} = $uname[0]; # like so: CYGWIN_NT-10.0-19043
		$distro->{'osr-skip'} = 1;
		push(@{$distro->{'method'}},'uname 0: cygwin');
	}
	if (!$distro->{'name'}){
		if (!$distro->{'osr-skip'} && @osr){
			$distro->{'name'} = get_osr();
			$distro->{'osr-skip'} = 1;
			push(@{$distro->{'method'}},'get_osr(): final');
		}
		elsif ($distro->{'lsb'}){
			$distro->{'name'} = get_lsb();
			push(@{$distro->{'method'}},'get_lsb(): final');
		}
	}
	# Now some final null tries
	if (!$distro->{'name'}){
		# If the file was null but present, which can happen in some cases, then use 
		# the file name itself to set the distro value. Why say unknown if we have 
		# a pretty good idea, after all?
		if ($distro->{'file'}){
			$distro->{'file'} =~ s/\/etc\/|[-_]|release|version//g;
			$distro->{'name'} = $distro->{'file'};
			push(@{$distro->{'method'}},'use: distro file name'); 
		}
	}
	main::feature_debugger('name: $distro: pre-base [linux]',$distro) if $distro->{'dbg'};
	system_base_linux() if $extra > 0;
	# Some last customized changes, double check if possible to verify still valid
	if ($distro->{'name'}){
		if ($distro->{'id'} eq 'armbian'){
			$distro->{'name'} =~ s/Debian/Armbian/;
			push(@{$distro->{'method'}},'custom: armbian name adjust'); 
		}
		elsif ($distro->{'id'} eq 'raspios'){
			$distro->{'base'} = $distro->{'name'};
			push(@{$distro->{'base-method'}},'custom: pi base from name'); 
			# No need to repeat the debian version info if base:
			if ($extra == 0){
			 $distro->{'name'} =~ s/Debian\s*GNU\/Linux/Raspberry Pi OS/;
			}
			else {
				$distro->{'name'} = 'Raspberry Pi OS';
			}
			push(@{$distro->{'method'}},'custom: pi name adjust'); 
		}
		# check for spins, relies on xdg directory name
		elsif ($distro->{'name'} =~ /^(Ubuntu)/i){
			my $base = $1;
			my $temp = distro_spin($distro->{'name'});
			if ($temp ne $distro->{'name'}){
				if (!$distro->{'base'} && $extra > 0){
					$distro->{'base'} = $base;
					push(@{$distro->{'base-method'}},'use: name');
				}
				$distro->{'name'} = $temp;
				push(@{$distro->{'method'}},'use: distro_spin()');
			}
		}
		elsif (-d '/etc/salixtools/' && $distro->{'name'} =~ /Slackware/i){
			$distro->{'name'} =~ s/Slackware/Salix/;
			push(@{$distro->{'method'}},'manual: name swap');
		}
		elsif ($distro->{'file'} =~ /($dist_file_no_name)/ && $distro->{'name'} =~ /^[\d\.]+$/){
			$distro->{'file'} =~ s/\/etc\/|[-_]|release|version//g;
			$distro->{'name'} = ucfirst($distro->{'file'}) . ' ' . $distro->{'name'};
			push(@{$distro->{'method'}},'use: file name');
		}
	}
	else {
		# android fallback, sometimes requires root, sometimes doesn't
		android_info() if $b_android;
	}
	## Finally, if all else has failed, give up
	$distro->{'name'} ||= 'unknown';
	if ($extra > 0 && $distro->{'name'} && $distro->{'base'}){
		check_base();
	}
	main::feature_debugger('name: $distro: final [linux]',$distro) if $distro->{'dbg'};
	eval $end if $b_log;
}

sub android_info {
	eval $start if $b_log;
	main::set_build_prop() if !$loaded{'build-prop'};;
	$distro->{'name'} = 'Android';
	$distro->{'name'} .= ' ' . $build_prop{'build-version'} if $build_prop{'build-version'};
	$distro->{'name'} .= ' ' . $build_prop{'build-date'} if $build_prop{'build-date'};
	if (!$show{'machine'}){
		if ($build_prop{'product-manufacturer'} && $build_prop{'product-model'}){
			$distro->{'name'} .= ' (' . $build_prop{'product-manufacturer'} . ' ' . $build_prop{'product-model'} . ')';
		}
		elsif ($build_prop{'product-device'}){
			$distro->{'name'} .= ' (' . $build_prop{'product-device'} . ')';
		}
		elsif ($build_prop{'product-name'}){
			$distro->{'name'} .= ' (' . $build_prop{'product-name'} . ')';
		}
	}
	eval $end if $b_log;
}

sub system_base_linux {
	eval $start if $b_log;
	$distro->{'osr-pretty'} = 0; # reset: if we want to use osr pretty, detect here.
	# Need data on these Arch derived: CachyOS; can be ArchLab/Labs
	my $base_distro_arch = 'anarchy|antergos|apricity';
	$base_distro_arch .= '|arch(bang|craft|ex|lab|man|strike)|arco|artix';
	$base_distro_arch .= '|blackarch|bluestar|bridge|cachyos|chakra|condres|ctlos';
	# note: arch linux derived distro page claims kaos as arch derived but it is NOT
	$base_distro_arch .= '|endeavour|feliz|garuda|hyperbola|linhes|liri';
	$base_distro_arch .= '|mabox|magpie|manjaro|mysys2|namib|netrunner\s?rolling|ninja';
	$base_distro_arch .= '|obarun|parabola|porteus|puppyrus-?a';
	$base_distro_arch .= '|reborn|revenge|salient|snal|steamos';
	$base_distro_arch .= '|talkingarch|theshell|ubos|velt|xero';
	my $base_file_debian_version = 'sidux';
	# detect debian steamos before arch steamos
	my $base_osr_debian_version = '\belive|blankon|lmde|neptune|nitrux|parrot|';
	$base_osr_debian_version .= 'pureos|rescatux|septor|solyd|sparky|steamos|tails';
	my $base_osr_devuan_version = 'crowz|dowse|etertics|\bexe\b|fluxuan|gnuinos|';
	$base_osr_devuan_version .= 'gobmis|heads|miyo|refracta|\bstar\b|virage';
	# osr has base ids
	my $base_default = 'antix-version|bodhi|mx-version'; 
	# base only found in issue
	my $base_issue = 'bunsen'; 
	# synthesize, no direct data available
	my $base_manual = 'deepin|kali'; 
	# osr base, distro id in list of distro files
	my $base_osr = 'aptosid|bodhi|grml|q4os|siduction|slax|zenwalk'; 
	# osr base, distro id in issue
	my $base_osr_issue = 'grml|linux lite|openmediavault'; 
	# same as rhel re VERSION_ID but likely only ID_LIKE=fedora
	my $base_osr_fedora = 'amahi|asahi|audinux|clearos|fx64|montana|nobara|qubes|';
	$base_osr_fedora .= 'risios|ultramarine|vortexbox';
	# osr has distro name but has fedora centos redhat ID_LIKE and VERSION_ID same
	# fedora not handled will fall to RHEL if contains centos string
	my $base_osr_redhat = 'almalinux|centos|eurolinux|oracle|puias|rocky|';
	$base_osr_redhat .= 'scientific|springdale'; 
	# osr has distro name but has ubuntu (or debian) ID_LIKE/UBUNTU_CODENAME
	my $base_osr_ubuntu = 'feren|mint|neon|nitrux|pop!?_os|tuxedo|zinc|zorin'; 
	my $base_upstream_lsb = '/etc/upstream-release/lsb-release';
	my $base_upstream_osr = '/etc/upstream-release/os-release';
	# These id as themselves, but system base is version file. Slackware mostly.
	my %base_version = (
	'porteux|salix|slackel|slint' => '/etc/slackware-version',
	);
	# First: try, some distros have upstream-release, elementary, new mint
	# and anyone else who uses this method for fallback ID
	if (-r $base_upstream_osr){
		my @osr_working = main::reader($base_upstream_osr);
		push(@{$distro->{'base-files'}},$base_upstream_osr) if $distro->{'dbg'};
		if (@osr_working){
			my @osr_temp = @osr;
			@osr = @osr_working;
			$distro->{'base'} = get_osr();
			@osr = @osr_temp if !$distro->{'base'};
			push(@{$distro->{'base-method'}},'get_osr(): upstream osr');
		}
	}
	# note: ultramarine trips this one but uses os-release field names, sigh, ignore
	elsif (-r $base_upstream_lsb){
		$distro->{'base'} = get_lsb($base_upstream_lsb);
		push(@{$distro->{'base-files'}},$base_upstream_lsb) if $distro->{'dbg'};
		push(@{$distro->{'base-method'}},'get_lsb(): upstream lsb');
	}
	dbg_distro_files('Linux base',$distro->{'base-files'}) if $distro->{'dbg'};
	# probably no need for these @osr greps, just grep $distro->{'name'} instead?
	if (!$distro->{'base'} && @osr){
		if ($etc_issue && (grep {/($base_issue)/i} @osr)){
			$distro->{'base'} = $etc_issue;
			push(@{$distro->{'base-method'}},'file: /etc/issue');
		}
		# more tests added here for other ubuntu derived distros
		elsif (@{$distro->{'files'}} && (grep {/($base_default)/} @{$distro->{'files'}})){
			$distro->{'base-type'} = 'default';
		}
		# must go before base_osr_arch,ubuntu tests. For steamos, use fallback arch
		elsif (grep {/($base_osr_debian_version)/i} @osr){
			$distro->{'base'} = debian_id('debian');
			push(@{$distro->{'base-method'}},'use: debian_id(debian)');
		}
		elsif (grep {/($base_osr_devuan_version)/i} @osr){
			$distro->{'base'} = debian_id('devuan');
			push(@{$distro->{'base-method'}},'use: debian_id(devuan)');
		}
		elsif (grep {/($base_osr_fedora)/i} @osr){
			$distro->{'base-type'} = 'fedora';
		}
		elsif (grep {/($base_osr_redhat)/i} @osr){
			$distro->{'base-type'} = 'rhel';
		}
		elsif (grep {/($base_osr_ubuntu)/i} @osr){
			$distro->{'base-type'} = 'ubuntu';
		}
		elsif ((($distro->{'id'} && $distro->{'id'} =~ /($base_osr_issue)/) || 
		 (@{$distro->{'files'}} && (grep {/($base_osr)/} @{$distro->{'files'}}))) && 
		 !(grep {/($base_osr)/i} @osr)){
			$distro->{'base'} = get_osr();
			push(@{$distro->{'base-method'}},'get_osr(): issue match');
		}
		if (!$distro->{'base'} && $distro->{'base-type'}){
			$distro->{'base'} = get_osr($distro->{'base-type'});
			push(@{$distro->{'base-method'}},'get_osr(): base-type');
		}
	}
	if (!$distro->{'base'} && @{$distro->{'files'}} && 
	 (grep {/($base_file_debian_version)/i} @{$distro->{'files'}})){
		$distro->{'base'} = debian_id('debian');
		push(@{$distro->{'base-method'}},'debian_id(debian): base_file_debian_version');
	}
	if (!$distro->{'base'} && $lc_issue && $lc_issue =~ /($base_manual)/){
		my $id = $1;
		my %manual = (
		# 'blankon' => 'Debian unstable', # use /etc/debian_version
		'deepin' => 'Debian unstable',
		'kali' => 'Debian testing',
		);
		$distro->{'base'} = $manual{$id};
		push(@{$distro->{'base-method'}},'manual: /etc/issue match');
	}
	if (!$distro->{'base'} && $distro->{'name'}){
		if ($distro->{'name'} =~ /^($base_distro_arch)/i){
			$distro->{'base'} = 'Arch Linux';
			push(@{$distro->{'base-method'}},'name-match: assign arch');
		}
		elsif ($distro->{'name'} =~ /^peppermint/i){
			my $type = (-f '/etc/devuan_version') ? 'devuan': 'debian';
			$distro->{'base'} = debian_id($type);
			push(@{$distro->{'base-method'}},'debian_id(): type');
		}
	}
	if (!$distro->{'base'} && $distro->{'name'}){
		foreach my $key (keys %base_version){
			if (-r $base_version{$key} && $distro->{'name'} =~ /($key)/i){
				$distro->{'base'} = main::reader($base_version{$key},'strip',0);
				$distro->{'base'} = main::clean_characters($distro->{'base'}) if $distro->{'base'};
				push(@{$distro->{'base-method'}},"base_version: file: $key");
				last;
			}
		}
	}
	if (!$distro->{'base'} && $distro->{'name'} && -d '/etc/salixtools/' && 
	$distro->{'name'} =~ /Slackware/i){
		$distro->{'base'} = $distro->{'name'};
		push(@{$distro->{'base-method'}},'custom: salix');
	}
	main::feature_debugger('$distro: base [linux]',$distro) if $distro->{'dbg'};
	eval $end if $b_log;
}

## PROCESS OS/LSB RELEASE ##
# Note: corner case when parsing the bodhi distro file
# args: 0: file name
sub get_lsb {
	eval $start if $b_log;
	my ($lsb_file) = @_;
	$lsb_file ||= '/etc/lsb-release';
	my ($dist_lsb,$id,$release,$codename,$description) = ('','','','','');
	my ($dist_id,$dist_release,$dist_code,$dist_desc) = ('DISTRIB_ID',
	'DISTRIB_RELEASE','DISTRIB_CODENAME','DISTRIB_DESCRIPTION');
	if ($lsb_file eq '/etc/bodhi/info'){
		$id = 'Bodhi Linux';
		# note: No ID field, hard code
		($dist_id,$dist_release,$dist_code,$dist_desc) = ('ID','RELEASE',
		'CODENAME','DESCRIPTION');
	}
	my @content = main::reader($lsb_file);
	main::log_data('dump','@content',\@content) if $b_log;
	@content = map {s/,|\*|\\||\"|[:\47]|^\s+|\s+$|n\/a//ig; $_} @content if @content;
	foreach (@content){
		next if /^\s*$/;
		my @working = split(/\s*=\s*/, $_);
		next if !$working[0];
		if ($working[0] eq $dist_id && $working[1]){
			if ($working[1] =~ /^Manjaro/i){
				$id = 'Manjaro Linux';
			}
			# in the old days, arch used lsb_release
			#	elsif ($working[1] =~ /^Arch$/i){
			#		$id = 'Arch Linux';
			#	}
			else {
				$id = $working[1];
			}
		}
		elsif ($working[0] eq $dist_release && $working[1]){
			$release = $working[1];
		}
		elsif ($working[0] eq $dist_code && $working[1]){
			$codename = $working[1];
		}
		# sometimes some distros cannot do their lsb-release files correctly, 
		# so here is one last chance to get it right.
		elsif ($working[0] eq $dist_desc && $working[1]){
			$description = $working[1];
		}
	}
	if (!$id && !$release && !$codename && $description){
		$dist_lsb = $description;
	}
	else {
		# avoid duplicates
		$dist_lsb = $id;
		$dist_lsb .= " $release" if $release && $dist_lsb !~ /$release/;
		# eg: release: 9 codename: mga9
		if ($codename && $dist_lsb !~ /$codename/i && 
		(!$release || $codename !~ /$release/)){
			$dist_lsb .= " $codename";
		}
		$dist_lsb =~ s/^\s+|\s\s+|\s+$//g; # get rid of double and trailing spaces 
	}
	eval $end if $b_log;
	return $dist_lsb;
}

sub get_osr {
	eval $start if $b_log;
	my ($base_type) = @_;
	my ($base_id,$base_name,$base_version,$dist_osr,$name,$name_lc,$name_pretty,
	$version_codename,$version_name,$version_id) = ('','','','','','','','','','');
	my @content = @osr;
	main::log_data('dump','@content',\@content) if $b_log;
	@content = map {s/\\||\"|[:\47]|^\s+|\s+$|n\/a//ig; $_} @content if @content;
	foreach (@content){
		next if /^\s*$/;
		my @working = split(/\s*=\s*/, $_);
		next if !$working[0];
		if ($working[0] eq 'PRETTY_NAME' && $working[1]){
			$name_pretty = $working[1];
		}
		elsif ($working[0] eq 'NAME' && $working[1]){
			$name = $working[1];
			$name_lc = lc($name);
		}
		elsif ($working[0] eq 'VERSION_CODENAME' && $working[1]){
			$version_codename = $working[1];
		}
		elsif ($working[0] eq 'VERSION' && $working[1]){
			$version_name = $working[1];
			$version_name =~ s/,//g;
		}
		elsif ($working[0] eq 'VERSION_ID' && $working[1]){
			$version_id = $working[1];
		}
		# for mint/zorin, other ubuntu base system base
		if ($base_type){
			if ($working[0] eq 'ID_LIKE' && $working[1]){
				if ($base_type eq 'ubuntu'){
					# feren,popos shows debian, feren ID ubuntu
					$working[1] =~ s/^(debian|ubuntu\sdebian|debian\subuntu)/ubuntu/; 
					$base_name = ucfirst($working[1]);
				}
				elsif ($base_type eq 'fedora' && $working[1] =~ /fedora/i){
					$base_name = 'Fedora';
					$base_version = $version_id if $version_id;
				}
				# oracle ID_LIKE="fedora". Why? who knows.
				elsif ($base_type eq 'rhel' && $working[1] =~ /rhel|fedora/i){
					$base_name = 'RHEL';
					$base_version = $version_id if $version_id;
				}
				elsif ($base_type eq 'arch' && $working[1] =~ /$base_type/i){
					$base_name = 'Arch Linux';
				}
				else {
					$base_name = ucfirst($working[1]);
				}
			}
			elsif ($base_type eq 'ubuntu' && $working[0] eq 'UBUNTU_CODENAME' && $working[1]){
				$base_version = ucfirst($working[1]);
			}
			elsif ($base_type eq 'debian' && $working[0] eq 'DEBIAN_CODENAME' && $working[1]){
				$base_version = $working[1];
			}
		}
	}
	# NOTE: tumbleweed has pretty name but pretty name does not have version id
	# arco shows only the release name, like kirk, in pretty name. Too many distros 
	# are doing pretty name wrong, and just putting in the NAME value there
	if (!$base_type){
		if ((!$distro->{'osr-pretty'} || !$name_pretty) && $name && $version_name){
			$dist_osr = $name;
			$dist_osr = 'Arco Linux' if $name_lc =~ /^arco/;
			if ($version_id && $version_name !~ /$version_id/){
				$dist_osr .= ' ' . $version_id;
			}
			$dist_osr .= " $version_name";
		}
		elsif ($name_pretty && ($name_pretty !~ /tumbleweed/i && $name_lc ne 'arcolinux')){
			$dist_osr = $name_pretty;
		}
		elsif ($name){
			$dist_osr = $name;
			if ($version_id){
				$dist_osr .= ' ' . $version_id;
			}
		}
		if ($version_codename && $dist_osr !~ /$version_codename/i){
			my @temp = split(/\s*[\/\s]\s*/, $version_codename);
			foreach (@temp){
				if ($dist_osr !~ /\b$_\b/i){
					$dist_osr .= " $_";
				}
			}
		}
	}
	# note: mint has varying formats here, some have ubuntu as name, 17 and earlier
	else {
		# incoherent feren use of version, id, etc
		if ($base_type eq 'ubuntu' && !$base_version && $version_codename && 
		$name =~ /feren/i){
			$base_version = ucfirst($version_codename);
			$distro->{'name'} =~ s/ $version_codename//;
		}
		# mint 17 used ubuntu os-release, so won't have $base_version, steamos holo
		if ($base_name && ($base_type eq 'fedora' || $base_type eq 'rhel')){
			$dist_osr = $base_name;
			$dist_osr .= ' ' . $version_id if $version_id; 
		}
		elsif ($base_name && $base_type eq 'arch'){
			$dist_osr = $base_name;
		}
		elsif ($base_name && $base_version){
			$base_id = ubuntu_id($base_version) if $base_type eq 'ubuntu' && $base_version;
			$base_id = '' if $base_id && "$base_name$base_version" =~ /$base_id/;
			$base_id .= ' ' if $base_id;
			$dist_osr = "$base_name $base_id$base_version";
		}
		elsif ($base_type eq 'default' && ($name_pretty || ($name && $version_name))){
			$dist_osr = ($name && $version_name) ? "$name $version_name" : $name_pretty;
		}
		# LMDE 2 has only limited data in os-release, no _LIKE values. 3 has like and debian_codename
		elsif ($base_type eq 'ubuntu' && $name_lc =~ /^(debian|ubuntu)/ && 
		($name_pretty || ($name && $version_name))){
			$dist_osr = ($name && $version_name) ? "$name $version_name": $name_pretty;
		}
		elsif ($base_type eq 'debian' && $base_version){
			$dist_osr = debian_id('debian',$base_version);
		}
		# not used yet
		elsif ($base_type eq 'devuan' && $base_version){
			$dist_osr = debian_id('devuan',$base_version);
		}
	}
	eval $end if $b_log;
	return $dist_osr;
}

## ID MATCHING TABLES ##
# args: 0: distro string
# note: relies on /etc/xdg/xdg-[distro-id] which is an ubuntu thing but could 
# work if other distros use that for spins. Xebian does but not official spin.
sub distro_spin {
	my $name = $_[0];
	eval $start if $b_log;
	my @spins = (
	# 0: distro name; 1: xdg search; 2: env search; 3: print name; 4: System Base
	['budgie','budgie','','Ubuntu Budgie','Ubuntu'],
	['cinnamon','cinnamon','','Ubuntu Cinnamon','Ubuntu'],
	['edubuntu','edubuntu','edubuntu','Edubuntu','Ubuntu'],
	# ['icebox','icebox','icebox','Debian Icebox','Debian'],
	['kubuntu','kubuntu|plasma','kubuntu','Kubuntu','Ubuntu'],
	['kylin','kylin','kylin','Ubuntu Kylin','Ubuntu'],
	['lubuntu','lubuntu','lubuntu','Lubuntu','Ubuntu'],
	['mate','mate','','Ubuntu MATE','Ubuntu'],
	['studio','studio','studio','Ubuntu Studio','Ubuntu'],
	['unity','unity','','Ubuntu Unity','Ubuntu'],
	# ['xebian','xebian','','Xebian','Debian'],
	['xubuntu','xubuntu','xubuntu','Xubuntu','Ubuntu'],
	);
	my $tests = 'budgie,cinna,edub,plasma,kubu,kylin,lubu,mate,studio,unity,xebi,xubu';
	$tests = join(':',main::globber("/etc/xdg/xdg-*{$tests}*"));
	# xdg is poor since only works in gui. Some of these also in DESKTOP_SESSION
	foreach my $spin (@spins){
		if ($name !~ /$spin->[0]/i && (
		($spin->[2] && $ENV{'DESKTOP_SESSION'} && 
		$ENV{'DESKTOP_SESSION'} =~ /$spin->[2]/i) || 
		($ENV{'XDG_CONFIG_DIRS'} && $ENV{'XDG_CONFIG_DIRS'} =~ /$spin->[1]/i) || 
		($tests && $tests =~ /$spin->[1]/i))){
			$name =~ s/\b$spin->[4]/$spin->[3]/i;
			last;
		}
	}
	eval $end if $b_log;
	return $name;
}

# args: 0: $type [debian|devuan]; 1: optional: debian codename
sub debian_id {
	eval $start if $b_log;
	my ($type,$codename) = @_;
	my ($id,$file_value,%releases,$version);
	if (-r "/etc/${type}_version"){
		$file_value = main::reader("/etc/${type}_version",'strip',0);
	}
	return if !$file_value && !$codename;
	if ($type eq 'debian'){
		$id = 'Debian';
		# note, 3.0, woody, 3.1, sarge, but after it's integer per version
		%releases = (
		'4' => 'etch',
		'5' => 'lenny',
		'6' => 'squeeze',
		'7' => 'wheezy',
		'8' => 'jessie',
		'9' => 'stretch',
		'10' => 'buster',
		'11' => 'bullseye',
		'12' => 'bookworm', 
		'13' => 'trixie',
		'14' => 'forky',
		);
	}
	else {
		$id = 'Devuan';
		%releases = (
		'1' => 'jesse',    # jesse
		'2' => 'ascii',    # stretch
		'3' => 'beowolf',  # buster
		'4' => 'chimaera', # bullseye
		'5' => 'daedalus', # bookworm
		'6' => 'excalibur',# trixie
		'7' => 'freia',    # forky
		# '' => 'ceres/daedalus',    # sid/unstable
		);
	}
	# debian often numeric, devuan usually not
	# like trixie/sid; daedalus; ceres/daedalus; 12.0
	if (main::is_numeric($file_value)){
		$version = $file_value . ' ' . $releases{int($file_value)};
	}
	else {
		my %releases_r = reverse %releases;
		if ($codename){
			$version = ($releases_r{$codename}) ? "$releases_r{$codename} $codename": $codename;
		}
		elsif ($releases_r{$file_value}) {
			$version = "$releases_r{$file_value} $file_value";
		}
		else {
			$version = $file_value;
		}
	}
	if ($version){
		my @temp = split(/\s*[\/\s]\s*/, $version);
		foreach (@temp){
			if ($distro->{'name'} !~ /\b$_\b/i){
				$id .= " $_";
			}
		}
	}
	eval $end if $b_log;
	return $id;
}

# Note, these are only for matching distro/mint derived names.
# Update list as new names become available. While first Mint was 2006-08, 
# this method depends on /etc/os-release which was introduced 2012-02. 
# Mint is using UBUNTU_CODENAME without ID data.
sub ubuntu_id {
	eval $start if $b_log;
	my ($codename) = @_;
	$codename = lc($codename);
	my ($id) = ('');
	# xx.04, xx.10
	my %codenames = (
	# '??' => '26.04',
	# '??' => '25.10',
	# '??' => '25.04',
	# '??' => '24.10',
	'noble' => '24.04 LTS',
	'mantic' => '23.10',
	'lunar' => '23.04',
	'kinetic' => '22.10',
	'jammy' => '22.04 LTS',
	'impish' => '21.10',
	'hirsute' => '21.04',
	'groovy' => '20.10',
	'focal' => '20.04 LTS',
	'eoan' => '19.10',
	'disco' => '19.04',
	'cosmic' => '18.10',
	'bionic' => '18.04 LTS',
	'artful' => '17.10',
	'zesty' => '17.04',
	'yakkety' => '16.10',
	'xenial' => '16.04 LTS',
	'wily' => '15.10',
	'vivid' => '15.04',
	'utopic' => '14.10',
	'trusty' => '14.04 LTS ',
	'saucy' => '13.10',
	'raring' => '13.04',
	'quantal' => '12.10',
	'precise' => '12.04 LTS ',
	#	'natty' => '11.04','oneiric' => '11.10',
	#	'lucid' => '10.04','maverick' => '10.10',
	#	'jaunty' => '9.04','karmic' => '9.10',
	#	'hardy' => '8.04','intrepid' => '8.10',
	#	'feisty' => '7.04','gutsy' => '7.10',
	#	'dapper' => '6.06','edgy' => '6.10',
	#	'hoary' => '5.04','breezy' => '5.10',
	#	'warty' => '4.10', # warty was the first ubuntu release
	);
	$id = $codenames{$codename} if defined $codenames{$codename};
	eval $end if $b_log;
	return $id;
}

## UTILITIES ##
sub check_base {
	if (lc($distro->{'name'}) eq lc($distro->{'base'})){
		$distro->{'base'} = '';
	}
	else {
		my @name = split(/\s+/,$distro->{'name'});
		my @working;
		foreach my $word (@name){
			if ($distro->{'base'} !~ /\b\Q$word\E\b/i || $word =~ /^[\d\.]+$/){
				push(@working,$word);
			}
		}
		$distro->{'name'} = join(' ',@working) if @working;
	}
}

# args: 0: info; 1: list of globbed distro files
sub dbg_distro_files {
	my ($info,$files) = @_;
	my $contents = {};
	foreach my $file (@$files){
		$contents->{$file} = (-r $file ) ? main::reader($file,'','ref') : main::message('file-unreadable');
	}
	main::feature_debugger($info . ' raw distro files:',$contents);
}
}

## DmidecodeData 
{
package ShellData;
my $b_debug = 0; # disable all debugger output in case forget to comment out!

# Public. This does not depend on using ps -jfp, open/netbsd do not at this 
# point support it, so we only want to use -jp to get parent $ppid set in 
# initialize(). shell_launcher will use -f so it only runs in case we got 
# $pppid. $client{'pppid'} will be used to trigger launcher tests. If started 
# with sshd via ssh user@address 'pinxi -Ia' will show sshd as shell, which is 
# fine, that's what it is.
sub set {
	eval $start if $b_log;
	my (@app,$cmd,$parent,$pppid,$shell);
	$loaded{'shell-data'} = 1;
	$cmd = "ps -wwp $ppid -o comm= 2>/dev/null";
	$shell = qx($cmd);
	# we'll be using these $client pppid/parent values in shell_launcher() 
	$pppid = $client{'pppid'} = get_pppid($ppid);
	$pppid ||= ''; 
	$client{'pppid'} ||= '';
	# print "sh: $shell\n";
	main::log_data('cmd',$cmd) if $b_log;
	chomp($shell);
	if ($shell){
		# print "shell pre: $shell\n";
		# when run in debugger subshell, would return sh as shell,
		# and parent as perl, that is, pinxi itself, which is actually right.
		# trim leading /.../ off just in case. ps -p should return the name, not path 
		# but at least one user dataset suggests otherwise so just do it for all.
		$shell =~ s/^.*\///; 
		# NOTE: su -c "inxi -F" results in shell being su
		# but: su - results in $parent being su
		my $i=0;
		$parent = $client{'parent'} = parent_name($pppid) if $pppid;
		$parent ||= '';
		print "1: shell: $shell $ppid parent: $parent $pppid\n" if $b_debug;
 		# this will fail in this case: sudo su -c 'inxi -Ia'
		if ($shell =~ /^(doas|login|sudo|su)$/){
			$client{'su-start'} = $shell if $shell ne 'login';
			$shell = $parent if $parent;
		}
		# eg: su to root, then sudo
		elsif ($parent && $client{'parent'} =~ /^(doas|sudo|su)$/){
			$client{'su-start'} = $parent;
			$parent = '';
		}
		print "2: shell: $shell parent: $parent\n" if $b_debug;
		my $working = $ENV{'SHELL'};
		if ($working){
			$working =~ s/^.*\///;
			# a few manual changes for known 
			# Note: parent when fizsh shows as zsh but SHELL is fizsh, but other times
			# SHELL is default shell, but in zsh, SHELL is default shell, not zfs
			if ($shell eq 'zsh' && $working eq 'fizsh'){
				$shell = $working;
			}
		}
		# print "3: shell post: $shell working: $working\n";
		# since there are endless shells, we'll keep a list of non program value
		# set shells since there is little point in adding those to program values
		if (shell_test($shell)){
			# do nothing, just leave $shell as is
		}
		# note: not all programs return version data. This may miss unhandled shells!
		elsif ((@app = ProgramData::full(lc($shell),lc($shell),1)) && $app[0]){
			$shell = $app[0];
			$client{'version'} = $app[1] if $app[1]; 
			print "3: app test $shell v: $client{'version'}\n" if $b_debug;
		}
		else {
			# NOTE: we used to guess here with position 2 --version but this cuold lead
			# to infinite loops when inxi called from a script 'infos' that is in PATH and 
			# script does not have any start arg handlers or bad arg handlers: 
			# eg: shell -> infos -> inxi -> sh -> infos --version -> infos -> inxi...
			# Basically here we are hoping that the grandparent is a shell, or at least
			# recognized as a known possible program
			# print "app not shell?: $shell\n";
			if ($shell){
				 print "shell 4: $shell StartClientVersionType: $parent\n" if $b_debug;
				if ($parent){
					if (shell_test($parent)){
						$shell = $parent;
					}
					elsif ((@app = ProgramData::full(lc($parent),lc($parent),0)) && $app[0]){
						$shell = $app[0];
						$client{'version'} = $app[1] if $app[1];
					}
					print "shell 5: $shell version: $client{'version'}\n" if $b_debug;
				}
			}
			else {
				$client{'version'} = main::message('unknown-shell');
			}
			print "6: shell not app version: $client{'version'}\n" if $b_debug;
		}
		$client{'version'} ||= '';
		$client{'version'} =~ s/(\(.*|-release|-version)// if $client{'version'};
		$shell =~ s/^[\s-]+|[\s-]+$//g if $shell; # sometimes will be like -sh
		$client{'name'} = lc($shell);
		$client{'name-print'} = $shell;
		print "7: shell: $client{'name-print'} version: $client{'version'}\n" if $b_debug;
		if ($extra > 2 && $working && lc($shell) ne lc($working)){
			if (@app = ProgramData::full(lc($working))){
				$client{'default-shell'} = $app[0];
				$client{'default-shell-v'} = $app[1];
				$client{'default-shell-v'} =~ s/(\s*\(.*|-release|-version)// if $client{'default-shell-v'};
			}
			else {
				$client{'default-shell'} = $working;
			}
		}
	}
	else {
		# last fallback to catch things like busybox shells
		if (my $busybox = readlink(main::check_program('sh'))){
			if ($busybox =~ m|busybox$|){
				$client{'name'} = 'ash';
				$client{'name-print'} = 'ash (busybox)'; 
			}
		}
		print "8: shell: $client{'name-print'} version: $client{'version'}\n" if $b_debug;
		if (!$client{'name'}) {
			$client{'name'} = 'shell';
			# handling na here, not on output, so we can test for !$client{'name-print'}
			$client{'name-print'} = 'N/A';
		}
	}
	if (!$client{'su-start'}){
		$client{'su-start'} = 'sudo' if $ENV{'SUDO_USER'};
		$client{'su-start'} = 'doas' if $ENV{'DOAS_USER'};
	}
	if ($parent && $parent eq 'login'){
		$client{'su-start'} = ($client{'su-start'}) ? $client{'su-start'} . ',' . $parent: $parent;
	}
	eval $end if $b_log;
}

# Public: returns shell launcher, terminal, program, whatever
# depends on $pppid so only runs if that is set.
sub shell_launcher {
	eval $start if $b_log;
	my (@data);
	my ($msg,$pppid,$shell_parent) = ('','','');
	$pppid = $client{'pppid'};
	if ($b_log){
		$msg = ($ppid) ? "pppid: $pppid ppid: $ppid": "ppid: undefined";
		main::log_data('data',$msg);
	}
	# print "self parent: $pppid ppid: $ppid\n";
	if ($pppid){
		$shell_parent = $client{'parent'};
		# print "shell parent 1: $shell_parent\n";
		if ($b_log){
			$msg = ($shell_parent) ? "shell parent 1: $shell_parent": "shell parent 1: undefined";
			main::log_data('data',$msg);
		}
		# in case sudo starts inxi, parent is shell (or perl inxi if run by debugger)
		# so: perl (2) started pinxi with sudo (3) in sh (4) in terminal
		my $shells = 'ash|bash|busybox|cicada|csh|dash|doas|elvish|fish|fizsh|ksh|';
		$shells .= 'ksh93|lksh|login|loksh|mksh|nash|oh|oil|osh|pdksh|perl|posh|';
		$shells .= 'su|sudo|tcsh|xonsh|yash|zsh';
		$shells .= shell_test('return');
		my $i = 0;
		print "self::pppid-0: $pppid :: $shell_parent\n" if $b_debug;
		# note that new shells not matched will keep this loop spinning until it ends. 
		# All we really can do about that is update with new shell name when we find them. 
		while ($i < 8 && $shell_parent && $shell_parent =~ /^($shells)$/){
			# bash > su > parent
			$i++;
			$pppid = get_pppid($pppid);
			$shell_parent = parent_name($pppid);
			print "self::pppid-${i}: $pppid :: $shell_parent\n" if $b_debug;
			if ($b_log){
				$msg = ($shell_parent) ? "parent-$i: $shell_parent": "shell parent $i: undefined";
				main::log_data('data',$msg);
			}
		}
	}
	if ($b_log){
		$pppid ||= '';
		$shell_parent ||= '';
		main::log_data('data',"parents: pppid: $pppid parent-name: $shell_parent");
	}
	eval $end if $b_log;
	return $shell_parent;
}

# args: 0: parent id 
# returns SID/start ID
sub get_pppid {
	eval $start if $b_log;
	my ($ppid) = @_;
	return 0 if !$ppid;
	# ps -j -fp : some bsds ps do not have -f for PPID, so we can't get the ppid
	my $cmd = "ps -wwjfp $ppid 2>/dev/null";
	main::log_data('cmd',$cmd) if $b_log;
	my @data = main::grabber($cmd);
	# shift @data if @data;
	my $pppid = main::awk(\@data,"$ppid",3,'\s+');
	eval $end if $b_log;
	return $pppid;
}

# args: 0: parent id
# returns parent command name
sub parent_name {
	eval $start if $b_log;
	my ($ppid) = @_;
	return '' if !$ppid;
	my ($parent_name);
	# known issue, ps truncates long command names, like io.elementary.t[erminal]
	my $cmd = "ps -wwjp $ppid 2>/dev/null";
	main::log_data('cmd',$cmd) if $b_log;
	my @data = main::grabber($cmd,'','strip');
	# dump the headers if they exist
	$parent_name = (grep {/$ppid/} @data)[0] if @data;
	if ($parent_name){
		# we don't want to worry about column position, just slice off all 
		# the first part before the command
		$parent_name =~ s/^.*[0-9]+:[0-9\.]+\s+//;
		# then get the command
		$parent_name = (split(/\s+/,$parent_name))[0];
		# get rid of /../ path info if present
		$parent_name =~ s|^.*/|| if $parent_name; 
		# to work around a ps -p or gnome-terminal bug, which returns 
		# gnome-terminal- trim -/_ off start/end; _su, etc, which breaks detections
		$parent_name =~ s/^[_-]|[_-]$//g;
	}
	eval $end if $b_log;
	return $parent_name;
}

# List of program_values non-handled shells, or known to have no version
# Move shell to set_program_values for print name, or version if available
# args: 0: return|[shell name to test
# returns test list OR shell name/''
sub shell_test {
	my ($test) = @_;
	# these shells are not verified or tested
	my $shells = 'apush|ccsh|ch|esh?|eshell|heirloom|hush|';
	$shells .= 'ion|imrsh|larryshell|mrsh|msh(ell)?|murex|nsh|nu(shell)?|';
	$shells .= 'oksh|psh|pwsh|pysh(ell)?|rush|sash|xsh?|';
	# these shells are tested and have no version info
	$shells .= 'es|rc|scsh|sh';
	return '|' . $shells if $test eq 'return';
	return ($test =~ /^($shells)$/) ? $test : '';
}

# This will test against default IP like: (:0) vs full IP to determine 
# ssh status. Surprisingly easy test? Cross platform
sub ssh_status {
	eval $start if $b_log;
	my ($b_ssh,$ssh);
	# fred   pts/10       2018-03-24 16:20 (:0.0)
	# fred-remote pts/1        2018-03-27 17:13 (43.43.43.43)
	if (my $program = main::check_program('who')){
		$ssh = (main::grabber("$program am i 2>/dev/null"))[0];
		# crude IP validation, v6 ::::::::, v4 x.x.x.x
		if ($ssh && $ssh =~ /\(([:0-9a-f]{8,}|[1-9][\.0-9]{6,})\)$/){
			$b_ssh = 1;
		}
	}
	eval $end if $b_log;
	return $b_ssh;
}

# If IRC: called if root for -S, -G, or if not in display for user.
sub console_irc_tty {
	eval $start if $b_log;
	$loaded{'con-irc-tty'} = 1;
	# not set for root in or out of display
	if (defined $ENV{'XDG_VTNR'}){
		$client{'con-irc-tty'} = $ENV{'XDG_VTNR'};
	}
	else {
		# ppid won't work with name, so this is assuming there's only one client running
		# if in display, -G returns vt size, not screen dimensions in rowsxcols.
		$client{'con-irc-tty'} = main::awk(\@ps_aux,'.*\b' . $client{'name'} . '\b.*',7,'\s+');
		$client{'con-irc-tty'} =~ s/^(tty|\?)// if defined $client{'con-irc-tty'};
	}
	$client{'con-irc-tty'} = '' if !defined $client{'con-irc-tty'};
	main::log_data('data',"console-irc-tty:$client{'con-irc-tty'}") if $b_log;
	eval $end if $b_log;
}

sub tty_number {
	eval $start if $b_log;
	$loaded{'tty-number'} = 1;
	# note: ttyname returns undefined if pinxi is > redirected output
	# variants: /dev/pts/1 /dev/tty1 /dev/ttyp2 /dev/ttyra [hex number a]
	$client{'tty-number'} = POSIX::ttyname(1);
	# but tty direct works fine in that case
	if (!defined $client{'tty-number'} && (my $program = main::check_program('tty'))){
		chomp($client{'tty-number'} = qx($program 2>/dev/null));
		if (defined $client{'tty-number'} && $client{'tty-number'} =~ /^not/){
			undef $client{'tty-number'};
		}
	}
	if (defined $client{'tty-number'}){
		$client{'tty-number'} =~ s/^\/dev\/(tty)?//;
	}
	else {
		$client{'tty-number'} = '';
	}
	# systemd only item, usually same as tty in console, not defined
	# for root or non systemd systems.
	if (defined $ENV{'XDG_VTNR'} && $client{'tty-number'} ne '' && 
	 $ENV{'XDG_VTNR'} ne $client{'tty-number'}){
		$client{'tty-number'} = "$client{'tty-number'} (vt $ENV{'XDG_VTNR'})";
	}
	elsif ($client{'tty-number'} eq '' && defined $ENV{'XDG_VTNR'}){
		$client{'tty-number'} = $ENV{'XDG_VTNR'};
	}
	main::log_data('data',"tty:$client{'tty-number'}") if $b_log;
	eval $end if $b_log;
}
}

sub set_sysctl_data {
	eval $start if $b_log;
	return if !$alerts{'sysctl'} || $alerts{'sysctl'}->{'action'} ne 'use';
	my (@temp);
	# darwin sysctl has BOTH = and : separators, and repeats data. Why? 
	if (!$fake{'sysctl'}){
		# just on odd chance we hit a bsd with /proc/cpuinfo, don't want to
		# sleep 2x
		if ($use{'bsd-sleep'} && !$system_files{'proc-cpuinfo'}){
			if ($b_hires){
				eval 'Time::HiRes::usleep($sleep)';
			}
			else {
				select(undef, undef, undef, $cpu_sleep);
			}
		}
		@temp = grabber($alerts{'sysctl'}->{'path'} . " -a 2>/dev/null");
	}
	else {
		my $file;
		# $file = "$fake_data_dir/bsd/sysctl/obsd_6.1_sysctl_soekris6501_root.txt";
		# $file = "$fake_data_dir/bsd/sysctl/obsd_6.1sysctl_lenovot500_user.txt";
		## matches: compaq: openbsd-dmesg.boot-1.txt
		# $file = "$fake_data_dir/bsd/sysctl/openbsd-5.6-sysctl-1.txt"; 
		## matches: toshiba: openbsd-5.6-dmesg.boot-1.txt
		# $file = "$fake_data_dir/bsd/sysctl/openbsd-5.6-sysctl-2.txt"; 
		# $file = "$fake_data_dir/bsd/sysctl/obsd-6.8-sysctl-a-battery-sensor-1.txt"; 
		# @temp = reader($file);
	}
	foreach (@temp){
		$_ =~ s/\s*=\s*|:\s+/:/;
		$_ =~ s/\"//g;
		push(@{$sysctl{'main'}}, $_);
		# we're building these here so we can use these arrays per feature
		if ($use{'bsd-audio'} && /^hw\.snd\./){
			push(@{$sysctl{'audio'}}, $_); # not used currently, just test data
		}
		# note: we could use ac0 to indicate plugged in but messes with battery output
		elsif ($use{'bsd-battery'} && /^hw\.sensors\.acpi(bat|cmb)/){
			push(@{$sysctl{'battery'}}, $_);
		}
		# hw.cpufreq.temperature: 40780 :: dev.cpu0.temperature 
		# hw.acpi.thermal.tz2.temperature: 27.9C :: hw.acpi.thermal.tz1.temperature: 42.1C
		# hw.acpi.thermal.tz0.temperature: 42.1C
		elsif ($use{'bsd-sensor'} &&((/^hw\.sensors/ && !/^hw\.sensors\.acpi(ac|bat|cmb)/ && 
		 !/^hw\.sensors\.softraid/) || /^hw\.acpi\.thermal/ || /^dev\.cpu\.[0-9]+\.temp/)){
			push(@{$sysctl{'sensor'}}, $_);
		}
		# Must go AFTER sensor because sometimes freebsd puts sensors in dev.cpu
		# hw.l1dcachesize hw.l2cachesize
		elsif ($use{'bsd-cpu'} && (/^hw\.(busfreq|clock|n?cpu|l[123].?cach|model|smt)/ || 
			/^dev\.cpu/ || /^machdep\.(cpu|hlt_logical_cpus)/)){
			push(@{$sysctl{'cpu'}}, $_);
		}
		# only activate if using the diskname feature in dboot!! note assign to $dboot.
		elsif ($use{'bsd-disk'} && /^hw\.disknames/){
			push(@{$dboot{'disk'}}, $_);
		}
		elsif ($use{'bsd-kernel'} && /^kern.compiler_version/){
			push(@{$sysctl{'kernel'}}, $_);
		}
		elsif ($use{'bsd-machine'} && 
		 /^(hw\.|machdep\.dmi\.(bios|board|system)-)(date|product|serial(no)?|uuid|vendor|version)/){
			push(@{$sysctl{'machine'}}, $_);
		}
		# let's rely on dboot, we really just want the hardware specs for solid ID
		# elsif ($use{'bsd-machine'} && !$dboot{'machine-vm'} && 
		#	/(\bhvm\b|innotek|\bkvm\b|microsoft.*virtual machine|openbsd[\s-]vmm|qemu|qumranet|vbox|virtio|virtualbox|vmware)/i){
		#	push(@{$dboot{'machine-vm'}}, $_);
		# }
		elsif ($use{'bsd-memory'} && /^(hw\.(physmem|usermem)|Free Memory)/){
			push(@{$sysctl{'memory'}}, $_);
		}
		
		elsif ($use{'bsd-raid'} && /^hw\.sensors\.softraid[0-9]\.drive[0-9]/){
			push(@{$sysctl{'softraid'}}, $_);
		}
	}
	if ($dbg[7]){
		print("main\n", Dumper $sysctl{'main'});
		print("dboot-machine-vm\n", Dumper $dboot{'machine-vm'});
		print("audio\n", Dumper $sysctl{'audio'});
		print("battery\n", Dumper $sysctl{'battery'});
		print("cpu\n", Dumper $sysctl{'cpu'});
		print("kernel\n", Dumper $sysctl{'kernel'});
		print("machine\n", Dumper $sysctl{'machine'});
		print("memory\n", Dumper $sysctl{'memory'});
		print("sensors\n", Dumper $sysctl{'sensor'});
		print("softraid\n", Dumper $sysctl{'softraid'});
	}
	# this thing can get really long.
	if ($b_log){
		main::log_data('dump','$sysctl{main}',$sysctl{'main'});
		main::log_data('dump','$dboot{machine-vm}',$sysctl{'machine-vm'});
		main::log_data('dump','$sysctl{audio}',$sysctl{'audio'});
		main::log_data('dump','$sysctl{battery}',$sysctl{'battery'});
		main::log_data('dump','$sysctl{cpu}',$sysctl{'cpu'});
		main::log_data('dump','$sysctl{kernel}',$sysctl{'kernel'});
		main::log_data('dump','$sysctl{machine}',$sysctl{'machine'});
		main::log_data('dump','$sysctl{memory}',$sysctl{'memory'});
		main::log_data('dump','$sysctl{sensors}',$sysctl{'sensor'});
		main::log_data('dump','$sysctl{softraid}',$sysctl{'softraid'});
	}
	eval $end if $b_log;
}

sub get_uptime {
	eval $start if $b_log;
	my ($days,$hours,$minutes,$seconds,$sys_time,$uptime) = ('','','','','','');
	if (check_program('uptime')){
		$uptime = qx(uptime);
		$uptime = trimmer($uptime);
		if ($fake{'uptime'}){
			# $uptime = '2:58PM  up 437 days,  8:18, 3 users, load averages: 2.03, 1.72, 1.77';
			# $uptime = '04:29:08 up  3:18,  3 users,  load average: 0,00, 0,00, 0,00';
			# $uptime = '10:23PM  up 5 days, 16:17, 1 user, load averages: 0.85, 0.90, 1.00';
			# $uptime = '05:36:47 up 1 day,  3:28,  4 users,  load average: 1,88, 0,98, 0,62';
			# $uptime = '05:36:47 up 1 day,  3 min,  4 users,  load average: 1,88, 0,98, 0,62';
			# $uptime = '04:41:23 up  2:16,  load average: 7.13, 6.06, 3.41 # root openwrt';
			# $uptime = '9:51 PM  up 2 mins, 1 user, load average: 0:58, 0.27, 0.11';
			# $uptime = '05:36:47 up 3 min,  4 users,  load average: 1,88, 0,98, 0,62';
			# $uptime = '9:51 PM  up 49 secs, 1 user, load average: 0:58, 0.27, 0.11';
			# $uptime = '04:11am  up   0:00,  1 user,  load average: 0.08, 0.03, 0.01'; # openSUSE 13.1 (Bottle)
			# $uptime = '11:21:43  up 1 day  5:53,  4 users,  load average: 0.48, 0.62, 0.48'; # openSUSE Tumbleweed 20210515 
		}
		if ($uptime){
			# trim off and store system time and up, and cut off user/load data
			$uptime =~ s/^([0-9:])\s*([AP]M)?.+up\s+|,?\s*([0-9]+\suser|load).*$//gi;
			# print "ut: $uptime\n";
			if ($1){
				$sys_time = $1;
				$sys_time .= lc($2) if $2;
			}
			if ($uptime =~ /\b([0-9]+)\s+day[s]?\b/){
				$days = ($1 + 0) . 'd';
			}
			if ($uptime =~ /\b([0-9]{1,2}):([0-9]{1,2})\b/){
				$hours = ($1 + 0) . 'h';
				$minutes = ($2 + 0) . 'm';
			}
			else {
				if ($uptime =~ /\b([0-9]+)\smin[s]?\b/){
					$minutes = ($1 + 0) . 'm';
				}
				if ($uptime =~ /\b([0-9]+)\ssec[s]?\b/){
					$seconds = ($1 + 0) . 's';
				}
			}
			$days .= ' ' if $days && ($hours || $minutes || $seconds);
			$hours .= ' ' if $hours && $minutes;
			$minutes .= ' ' if $minutes && $seconds;
			$uptime = $days . $hours . $minutes . $seconds;
		}
	}
	$uptime ||= 'N/A';
	eval $end if $b_log;
	return $uptime;
}

## UsbData
# %usb array indexes
# 0: bus id / sort id
# 1: device id
# 2: path_id
# 3: path
# 4: class id
# 5: subclass id
# 6: protocol id
# 7: vendor:chip id
# 8: usb version
# 9: interfaces
# 10: ports
# 11: vendor 
# 12: product
# 13: device-name
# 14: type string
# 15: driver
# 16: serial
# 17: speed (bits, Si base 10, [MG]bps)
# 18: configuration - not used
# 19: power mW bsd only, not used yet
# 20: product rev number
# 21: driver_nu [bsd only]
# 22: admin usb rev info
# 23: rx lanes
# 24: tx lanes
# 25: speed (Bytes, IEC base 2, [MG]iBs
# 26: absolute path
{
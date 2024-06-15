package InitData;
my ($init,$init_version,$program) = ('','','');

sub get {
	eval $start if $b_log;
	my $runlevel = get_runlevel();
	my $default = ($extra > 1) ? get_runlevel_default() : '';
	my ($rc,$rc_version) = ('','');
	my $comm = (-r '/proc/1/comm') ? main::reader('/proc/1/comm','',0) : '';
	my $link = readlink('/sbin/init');
	# this test is pretty solid, if pid 1 is owned by systemd, it is systemd
	# otherwise that is 'init', which covers the rest of the init systems.
	# more data may be needed for other init systems. 
	# Some systemd cases no /proc/1/comm exists however :(
	if (($comm && $comm =~ /systemd/) || -e '/run/systemd/units'){
		$init = 'systemd';
		if ($program = main::check_program('systemd')){
			($init,$init_version) = ProgramData::full('systemd',$program);
		}
		if (!$init_version && ($program = main::check_program('systemctl'))){
			($init,$init_version) = ProgramData::full('systemd',$program);
		}
		if ($runlevel && $runlevel =~ /^\d$/){
			my $target = '';
			if ($runlevel == 1){
				$target = 'rescue';}
			elsif ($runlevel > 1 && $runlevel < 5){
				$target = 'multi-user';}
			elsif ($runlevel == 5){
				$target = 'graphical';}
			$runlevel = "$target ($runlevel)" if $target;
		}
	}
	if (!$init && $comm){
		# not verified
		if ($comm =~ /^31init/){
			$init = '31init';
			# no version, this is a 31 line C program
		}
		elsif ($comm =~ /epoch/){
			($init,$init_version) = ProgramData::full('epoch');
		}
		# if they fix dinit to show /proc/1/comm == dinit
		elsif ($comm =~ /^dinit/){
			($init,$init_version) = ProgramData::full('dinit');
		}
		elsif ($comm =~ /finit/){
			($init,$init_version) = ProgramData::full('finit');
		}
		# not verified
		elsif ($comm =~ /^hummingbird/){
			$init = 'Hummingbird';
			# no version data known. Complete if more info found.
		}
		# nosh can map service manager to systemctl, service, rcctl, at least.
		elsif ($comm =~ /^nosh/){
			$init = 'nosh';
		}
		# missing data: note, runit can install as a dependency without being the 
		# init system: http://smarden.org/runit/sv.8.html
		# NOTE: the proc test won't work on bsds, so if runit is used on bsds we 
		# will need more data
		elsif ($comm =~ /runit/){
			$init = 'runit';
			# no version data as of 2022-10-26
		}
		elsif ($comm =~ /^s6/){
			$init = 's6';
			# no version data as of 2022-10-26
		}
		elsif ($comm =~ /shepherd/){
			($init,$init_version) = ProgramData::full('shepherd');
		}
		# fallback for some inits that link to /sbin/init
		elsif ($comm eq 'init'){
			# shows /sbin/dinit-init but may change
			if (-e '/sbin/dinit' && $link && $link =~ /dinit/){
				($init,$init_version) = ProgramData::full('dinit');
			}
			elsif (-e '/sbin/openrc-init' && $link && $link =~ /openrc/){
				($init,$init_version) = openrc_data();
			}
		}
	}
	if (!$init){
		# openwrt/busybox /sbin/init hangs on --version command
		if (-e '/sbin/init' && $link && $link =~ /busybox/){
			($init,$init_version) =  ProgramData::full('busybox','/sbin/init');
		}
		# risky since we don't know which init it is. $comm == 'init'
		# output: /sbin/init --version: init (upstart 1.1); init (upstart 0.6.3)
		elsif (!%risc && !$link && main::globber('/{usr/lib,sbin,var/log}/upstart*') &&
		 ($init_version = ProgramData::version('init', 'upstart', '3','--version'))){
			$init = 'Upstart';
		}
		# surely more positive way to detect active
		elsif (main::check_program('launchctl')){
			$init = 'launchd';
		}
		# could be nosh or runit as well for BSDs, not handled yet
		elsif (-f '/etc/inittab'){
			$init = 'SysVinit';
			if (main::check_program('strings')){
				my @data = main::grabber('strings /sbin/init 2>/dev/null');
				$init_version = main::awk(\@data,'^version\s+[0-9]',2);
			}
		}
		elsif (-f '/etc/ttys'){
			$init = 'init (BSD)';
		}
	}
	if ((grep { /openrc/ } main::globber('/run/*openrc*')) || (grep {/openrc/} @ps_cmd)){
		if (!$init || $init ne 'OpenRC'){
			($rc,$rc_version) = openrc_data();
		}
		if (-r '/run/openrc/softlevel'){
			$runlevel = main::reader('/run/openrc/softlevel','',0);
		}
		elsif (-r '/var/run/openrc/softlevel'){
			$runlevel = main::reader('/var/run/openrc/softlevel','',0);
		}
		elsif ($program = main::check_program('rc-status')){
			$runlevel = (main::grabber("$program -r 2>/dev/null"))[0];
		}
	}
	eval $end if $b_log;
	return {
	'init-type' => $init,
	'init-version' => $init_version,
	'rc-type' => $rc,
	'rc-version' => $rc_version,
	'runlevel' => $runlevel,
	'default' => $default,
	};
}

sub openrc_data {
	eval $start if $b_log;
	my @result;
	# /sbin/openrc --version: openrc (OpenRC) 0.13
	if ($program = main::check_program('openrc')){
		@result = ProgramData::full('openrc',$program);
	}
	# /sbin/rc --version: rc (OpenRC) 0.11.8 (Gentoo Linux)
	elsif ($program = main::check_program('rc')){
		@result = ProgramData::full('rc',$program);
	}
	$result[0] ||= 'OpenRC';
	eval $end if $b_log;
	return @result;
}

# Check? /var/run/nologin for bsds?
sub get_runlevel {
	eval $start if $b_log;
	my $runlevel = '';
	if ($program = main::check_program('runlevel')){
		# variants: N 5; 3 5; unknown
		$runlevel = (main::grabber("$program 2>/dev/null"))[0];
		$runlevel = undef if $runlevel && lc($runlevel) eq 'unknown';
		$runlevel =~ s/^(\S\s)?(\d)$/$2/ if $runlevel;
		# print_line($runlevel . ";;");
	}
	eval $end if $b_log;
	return $runlevel;
}

# Note: it appears that at least as of 2014-01-13, /etc/inittab is going 
# to be used for default runlevel in upstart/sysvinit. systemd default is 
# not always set so check to see if it's linked.
sub get_runlevel_default {
	eval $start if $b_log;
	my @data;
	my $default = '';
	if ($program = main::check_program('systemctl')){
		# note: systemd systems do not necessarily have this link created
		my $systemd = '/etc/systemd/system/default.target';
		# faster to read than run
		if (-e $systemd){
			$default = readlink($systemd);
			$default =~ s/(.*\/|\.target$)//g if $default; 
		}
		if (!$default){
			$default = (main::grabber("$program get-default 2>/dev/null"))[0];
			$default =~ s/\.target$// if $default;
		}
	}
	if (!$default){
		# http://askubuntu.com/questions/86483/how-can-i-see-or-change-default-run-level
		# note that technically default can be changed at boot but for inxi purposes 
		# that does not matter, we just want to know the system default
		my $upstart = '/etc/init/rc-sysinit.conf';
		my $inittab = '/etc/inittab';
		if (-r $upstart){
			# env DEFAULT_RUNLEVEL=2
			@data = main::reader($upstart);
			$default = main::awk(\@data,'^env\s+DEFAULT_RUNLEVEL',2,'=');
		}
		# handle weird cases where null but inittab exists
		if (!$default && -r $inittab){
			@data = main::reader($inittab);
			$default = main::awk(\@data,'^id.*initdefault',2,':');
		}
	}
	eval $end if $b_log;
	return $default;
}
}

## IpData
{
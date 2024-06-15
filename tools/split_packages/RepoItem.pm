package RepoItem;
# easier to keep these package global, but undef after done
my (@dbg_files,$debugger_dir,%repo_keys);
my $num = 0;

sub get {
	eval $start if $b_log;
	($debugger_dir) = @_;
	my $rows = [];
	if ($extra > 0 && !$loaded{'package-data'}){
		my $packages = PackageData::get('main',\$num);
		for (keys %$packages){
			$rows->[0]{$_} = $packages->{$_};
		}
	}
	my $rows_start = scalar @$rows; # to test if we found more rows after
	$num = 0;
	if ($bsd_type){
		get_repos_bsd($rows);
	}
	else {
		get_repos_linux($rows);
	}
	if ($debugger_dir){
		@$rows = @dbg_files;
		undef @dbg_files;
		undef $debugger_dir;
		undef %repo_keys;
	}
	else {
		if ($rows_start == scalar @$rows){
			my $pm_missing;
			if ($bsd_type){
				$pm_missing = main::message('repo-data-bsd',$uname[0]);
			}
			else {
				$pm_missing = main::message('repo-data');
			}
			push(@$rows,{main::key($num++,0,1,'Alert') => $pm_missing});
		}
	}
	eval $end if $b_log;
	return $rows;
}

sub get_repos_linux {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@content,$data,@data2,@data3,@files,$repo,@repos);
	my ($key,$path);
	my $apk = '/etc/apk/repositories';
	my $apt = '/etc/apt/sources.list';
	my $apt_termux = '/data/data/com.termux/files/usr' . $apt;
	$apt = $apt_termux if -e $apt_termux; # for android termux
	my $cards = '/etc/cards.conf';
	my $dnf_conf = '/etc/dnf/dnf.conf';
	my $dnf_repo_dir = '/etc/dnf.repos.d/';
	my $eopkg_dir = '/var/lib/eopkg/';
	my $netpkg = '/etc/netpkg.conf';
	my $netpkg_dir = '/etc/netpkg.d';
	my $nix = '/etc/nix/nix.conf';
	my $pacman = '/etc/pacman.conf';
	my $pacman_g2 = '/etc/pacman-g2.conf';
	my $pisi_dir = '/etc/pisi/';
	my $portage_dir = '/etc/portage/repos.conf/';
	my $portage_gentoo_dir = '/etc/portage-gentoo/repos.conf/';
	my $sbopkg = '/etc/sbopkg/sbopkg.conf';
	my $sboui_backend = '/etc/sboui/sboui-backend.conf';
	my $scratchpkg = '/etc/scratchpkg.repo';
	my $slackpkg = '/etc/slackpkg/mirrors';
	my $slackpkg_plus = '/etc/slackpkg/slackpkgplus.conf';
	my $slapt_get = '/etc/slapt-get/';
	my $slpkg = '/etc/slpkg/repositories.toml';
	my $tazpkg = '/etc/slitaz/tazpkg.conf';
	my $tazpkg_mirror = '/var/lib/tazpkg/mirror';
	my $tce_app = '/usr/bin/tce';
	my $tce_file = '/opt/tcemirror';
	my $tce_file2 = '/opt/localmirrors';
	my $yum_conf = '/etc/yum.conf';
	my $yum_repo_dir = '/etc/yum.repos.d/';
	my $xbps_dir_1 = '/etc/xbps.d/';
	my $xbps_dir_2 = '/usr/share/xbps.d/';
	my $zypp_repo_dir = '/etc/zypp/repos.d/';
	my $b_test = 0;
	## apt: Debian, *buntus + derived (deb files);AltLinux, PCLinuxOS (rpm files)
	# Sometimes some yum/rpm repos may create apt repos here as well
	if (-f $apt || -d "$apt.d"){
		my ($apt_arch,$apt_comp,$apt_suites,$apt_types,@apt_urls,@apt_working,
		$b_apt_enabled,$file,$string);
		my $counter = 0;
		@files = main::globber("$apt.d/*.list");
		push(@files, $apt);
		# prefilter list for logging
		@files = grep {-f $_} @files; # may not have $apt file.
		main::log_data('data',"apt repo files:\n" . main::joiner(\@files, "\n", 'unset')) if $b_log;
		foreach (sort @files){
			# altlinux/pclinuxos use rpms in apt files, -r to be on safe side
			if (-r $_){
				$data = repo_builder($_,'apt','^\s*(deb|rpm)');
				push(@$rows,@$data);
			}
		}
		# @files = main::globber("$fake_data_dir/repo/apt/*.sources");
		@files = main::globber("$apt.d/*.sources");
		# prefilter list for logging, sometimes globber returns non-prsent files.
		@files = grep {-f $_} @files;
		# @files = ("$fake_data_dir/repo/apt/deb822-u193-3.sources",
		# "$fake_data_dir/repo/apt/deb822-u193-3.sourcesdeb822-u193-4-signed-by.sources");
		main::log_data('data',"apt deb822 repo files:\n" . main::joiner(\@files, "\n", 'unset')) if $b_log;
		foreach $file (@files){
			# critical: whitespace is the separator, no logical ordering of 
			# field names exists within each entry.
			@data2 = main::reader($file);
			# print Data::Dumper::Dumper \@data2;
			if (@data2){
				@data2 = map {s/^\s*$/~/;$_} @data2;
				push(@data2, '~');
			}
			push(@dbg_files, $file) if $debugger_dir;
			# print "$file\n";
			@apt_urls = ();
			@apt_working = ();
			$b_apt_enabled = 1;
			foreach my $row (@data2){
				# NOTE: the syntax of deb822 must be considered a bug, it's sloppy beyond belief.
				# deb822 supports line folding which starts with space
				# BUT: you can start a URIs: block of urls with a space, sigh.
				next if $row =~ /^\s+/ && $row !~ /^\s+[^#]+:\//; 
				# strip out line space starters now that it's safe 
				$row =~ s/^\s+//;
				# print "$row\n";
				if ($row eq '~'){
					if (@apt_working && $b_apt_enabled){
						# print "1: url builder\n";
						foreach $repo (@apt_working){
							$string = $apt_types;
							$string .= ' [arch=' . $apt_arch . ']' if $apt_arch;
							$string .= ' ' . $repo;
							$string .= ' ' . $apt_suites if $apt_suites ;
							$string .= ' ' . $apt_comp if $apt_comp;
							# print "s1:$string\n";
							push(@data3, $string);
						}
						# print join("\n",@data3),"\n";
						push(@apt_urls,@data3);
					}
					@data3 = ();
					@apt_working = ();
					$apt_arch = '';
					$apt_comp = '';
					$apt_suites = '';
					$apt_types = '';
					$b_apt_enabled = 1;
				}
				elsif ($row =~ /^Types:\s*(.*)/i){
					# print "1:$1\n";
					$apt_types = $1;
				}
				elsif ($row =~ /^Enabled:\s*(.*)/i){
					$b_apt_enabled = ($1 =~ /\b(disable|false|off|no|without)\b/i) ? 0: 1;
				}
				elsif ($row =~ /^[^#]+:\//){
					my $url = $row;
					$url =~ s/^URIs:\s*//i;
					push(@apt_working, $url) if $url;
				}
				elsif ($row =~ /^Suites:\s*(.*)/i){
					$apt_suites = $1;
				}
				elsif ($row =~ /^Components:\s*(.*)/i){
					$apt_comp = $1;
				}
				elsif ($row =~ /^Architectures:\s*(.*)/i){
					$apt_arch = $1;
				}
			}
			if (@apt_urls){
				$key = repo_data('active','apt');
				clean_url(\@apt_urls);
			}
			else {
				$key = repo_data('missing','apt');
			}
			push(@$rows, 
			{main::key($num++,1,1,$key) => $file},
			[@apt_urls],
			);
		}
		@files = ();
	}
	## pacman, pacman-g2: Arch + derived, Frugalware
	if (-f $pacman || -f $pacman_g2){
		$repo = 'pacman';
		if (-f $pacman_g2){
			$pacman = $pacman_g2;
			$repo = 'pacman-g2';
		}
		@files = main::reader($pacman,'strip');
		if (@files){
			@repos = grep {/^\s*Server/i} @files;
			@files = grep {/^\s*Include/i} @files;
		}
		if (@files){
			@files = map {
				my @working = split(/\s+=\s+/, $_); 
				$working[1];
			} @files;
		}
		@files = sort @files;
		main::uniq(\@files);
		unshift(@files, $pacman) if @repos;
		foreach (@files){
			if (-f $_){
				$data = repo_builder($_,$repo,'^\s*Server','\s*=\s*',1);
				push(@$rows,@$data);
			}
			else {
				# set it so the debugger knows the file wasn't there
				push(@dbg_files, $_) if $debugger_dir;
				push(@$rows, 
				{main::key($num++,1,1,'File listed in') => $pacman},
				[("$_ does not seem to exist.")],
				);
			}
		}
		if (!@$rows){
			push(@$rows, 
			{main::key($num++,0,1,repo_data('missing','files')) => $pacman },
			);
		}
	}
	## netpkg: Zenwalk, Slackware
	if (-f $netpkg){
		my @data2 = ($netpkg);
		if (-d $netpkg_dir){
			@data3 = main::globber("$netpkg_dir/*");
			@data3 = grep {!/\/local$/} @data3 if @data3; # package directory
			push(@data2,@data3) if @data3;
		}
		foreach my $file (@data2){
			$data = repo_builder($file,'netpkg','^URL\s*=','\s*=\s*',1);
			push(@$rows,@$data);
		}
	}
	## sbopkg, sboui, slackpkg, slackpkg+, slapt_get, slpkg: Slackware + derived
	# $slpkg = "$fake_data_dir/repo/slackware/slpkg-2.toml";
	# $sbopkg = "$fake_data_dir/repo/slackware/sbopkg-2.conf";
	# $sboui_backend = "$fake_data_dir/repo/slackware/sboui-backend-1.conf";
	if (-f $slackpkg || -f $slackpkg_plus || -d $slapt_get || -f $slpkg || 
	 -f $sbopkg || -f $sboui_backend){
		if (-f $sbopkg){
			my $sbo_root = '/root/.sbopkg.conf';
			# $sbo_root = "$fake_data_dir/repo/slackware/sbopkg-root-1.conf";
			@files = ($sbopkg);
			# /root not readable as user, unless it is, so just check if readable
			push(@files,$sbo_root) if -r $sbo_root;
			my ($branch,$name);
			# SRC_REPO repo URL not used, not what we think
			foreach my $file (@files){
				foreach my $row (main::reader($file,'strip')){
					if ($row =~ /^REPO_NAME=(\S\{REPO_NAME:-)?(.*?)\}?$/){
						$name = $2;
					}
					elsif ($row =~ /^REPO_BRANCH=(\S\{REPO_BRANCH:-)?(.*?)\}?$/){
						$branch = $2;
					}
				}
			}
			# First found overridden by next, so we don't care where the value came 
			# from. We do care if 1 file and not root however, since might be wrong. 
			if ($branch && $name){
				if ($b_root || scalar @files == 2){
					$key = repo_data('active','sbopkg');
				}
				else {
					$key = repo_data('active-permissions','sbopkg');
				}
				@content = ("$name ~ $branch");
			}
			else {
				$key = repo_data('missing','sbopkg');
			}
			my @data = (
			{main::key($num++,1,1,$key) => join(', ',@files)},
			[@content],
			);
			push(@$rows,@data);
			(@content,@files) = ();
		}
		if (-f $sboui_backend){
			my ($branch,$repo);
			# Note: sboui also has a sboui.conf file, with the package_manager string
			# but that is too hard to handle clearly in output so leaving aside.
			foreach my $row (main::reader($sboui_backend,'strip')){
				if ($row =~ /^REPO\s*=\s*["']?(\S+?)["']?\s*$/){
					$repo = $1;
				}
				elsif ($row =~ /^BRANCH\s*=\s*["']?(\S+?)["']?\s*$/){
					$branch = $1;
				}
			}
			if ($repo){
				$key = repo_data('active','sboui');
				$branch = 'current' if !$branch || $repo =~ /ponce/i;
				@content = ("SBo $branch ~ $repo"); # we want SBo name to show
			}
			else {
				$key = repo_data('missing','sboui');
			}
			my @data = (
			{main::key($num++,1,1,$key) => $sboui_backend},
			[@content],
			);
			push(@$rows,@data);
			@content = ();
		}
		if (-f $slackpkg){
			$data = repo_builder($slackpkg,'slackpkg','^[[:space:]]*[^#]+');
			push(@$rows,@$data);
		}
		if (-d $slapt_get){
			@data2 = main::globber("${slapt_get}*");
			@data2 = grep {!/pubring/} @data2 if @data2;
			foreach my $file (@data2){
				$data = repo_builder($file,'slaptget','^\s*SOURCE','\s*=\s*',1);
				push(@$rows,@$data);
			}
		}
		if (-f $slackpkg_plus){
			push(@dbg_files, $slackpkg_plus) if $debugger_dir;
			my (@repoplus_list,$active_repos);
			foreach my $row (main::reader($slackpkg_plus,'strip')){
				@data2 = split(/\s*=\s*/, $row);
				@data2 = map { $_ =~ s/^\s+|\s+$//g ; $_ } @data2;
				last if $data2[0] =~ /^SLACKPKGPLUS/i && $data2[1] eq 'off';
				# REPOPLUS=(slackpkgplus restricted alienbob ktown multilib slacky)
				if ($data2[0] =~ /^REPOPLUS/i){
					@repoplus_list = split(/\s+/, $data2[1]);
					@repoplus_list = map {s/\(|\)//g; $_} @repoplus_list;
					$active_repos = join('|',@repoplus_list);
					
				}
				# MIRRORPLUS['multilib']=http://taper.alienbase.nl/mirrors/people/alien/multilib/14.1/
				if ($active_repos && $data2[0] =~ /^MIRRORPLUS/i){
					$data2[0] =~ s/MIRRORPLUS\[\'|\'\]//ig;
					if ($data2[0] =~ /$active_repos/){
						push(@content,"$data2[0] ~ $data2[1]");
					}
				}
			}
			if (!@content){
				$key = repo_data('missing','slackpkg+');
			}
			else {
				clean_url(\@content);
				$key = repo_data('active','slackpkg+');
			}
 			my @data = (
			{main::key($num++,1,1,$key) => $slackpkg_plus},
			[@content],
			);
			push(@$rows,@data);
			@content = ();
		}
		if (-f $slpkg){
			my ($active,$name,$repo);
			my $holder = '';
			@data2 = main::reader($slpkg);
			# We can't rely on the presence of empty lines as block separator.
			push(@data2,'-eof-') if @data2;
			# print Data::Dumper::Dumper \@data2;
			# old: "https://download.salixos.org/x86_64/slackware-15.0/"
			# new: ["https://slac...nl/people/alien/sbrepos/", "15.0/", "x86_64/"]
			foreach (@data2){
				next if /^\s*([#\[]|$)/;
				$_ = lc($_);
				if (/^\s*(\S+?)_(repo(|_name|_mirror))\s*=\s*[\['"]{0,2}(.*?)[\]'"]{0,2}\s*$/ ||
				$_ eq '-eof-'){
					my ($key,$value) = ($2,$4);
					if (($1 && $holder ne $1) || $_ eq '-eof-'){
						$holder = $1;
						if ($name && $repo){
							if (!$active || $active =~ /^(true|1|yes)$/i){
								push(@content,"$name ~ $repo");
							}
							($active,$name,$repo) = ();
						}
					}
					if ($key){
						if ($key eq 'repo'){
							$active = $value;}
						elsif ($key eq 'repo_name'){
							$name = $value;}
						elsif ($key eq 'repo_mirror'){
							# map new form to a real url
							$value =~ s/['"],\s*['"]//g;
							$repo = $value;}
					}
				}
			}
			if (!@content){
				$key = repo_data('missing','slpkg');
			}
			else {
				# Special case, sbo and ponce true, dump sbo, they conflict.
				# slpkg does this internally so no other way to handle.
				if (grep {/^ponce ~/} @content){
					@content = grep {!/sbo ~/} @content;
				}
				clean_url(\@content);
				$key = repo_data('active','slpkg');
			}
			push(@$rows, 
			{main::key($num++,1,1,$key) => $slpkg},
			[@content],
			);
			(@content,@data2,@data3) = ();
		}
	}
	## dnf, yum, zypp: Redhat, Suse + derived (rpm based)
	if (-f $dnf_conf  ||-d $dnf_repo_dir|| -d $yum_repo_dir || -f $yum_conf || 
	 -d $zypp_repo_dir){
		@files = ();
		push(@files, $dnf_conf) if -f $dnf_conf;
		push(@files, main::globber("$dnf_repo_dir*.repo")) if -d $dnf_repo_dir;
		push(@files, $yum_conf) if -f $yum_conf;
		push(@files, main::globber("$yum_repo_dir*.repo")) if -d $yum_repo_dir;
		if (-d $zypp_repo_dir){
			push(@files, main::globber("$zypp_repo_dir*.repo"));
			main::log_data('data',"zypp repo files:\n" . main::joiner(\@files, "\n", 'unset')) if $b_log;
		}
 		# push(@files, "$fake_data_dir/repo/yum/rpmfusion-nonfree-1.repo");
		if (@files){
			foreach (sort @files){
				@data2 = main::reader($_);
				push(@dbg_files, $_) if $debugger_dir;
				if (/yum/){
					$repo = 'yum';
				}
				elsif (/dnf/){
					$repo = 'dnf';
				}
				elsif(/zypp/){
					$repo = 'zypp';
				}
				my ($enabled,$url,$title) = (undef,'','');
				foreach my $line (@data2){
					# this is a hack, assuming that each item has these fields listed, we collect the 3
					# items one by one, then when the url/enabled fields are set, we print it out and
					# reset the data. Not elegant but it works. Note that if enabled was not present
					# we assume it is enabled then, and print the line, reset the variables. This will
					# miss the last item, so it is printed if found in END
					if ($line =~ /^\[(.+)\]/){
						my $temp = $1;
						if ($url && $title && defined $enabled){
							if ($enabled > 0){
								push(@content, "$title ~ $url");
							}
							($enabled,$url,$title) = (undef,'','');
						}
						$title = $temp;
					}
					# Note: it looks like enabled comes before url
					elsif ($line =~ /^(metalink|mirrorlist|baseurl)\s*=\s*(.*)/i){
						$url = $2;
					}
					# note: enabled = 1. enabled = 0 means disabled
					elsif ($line =~ /^enabled\s*=\s*(0|1|No|Yes|True|False)/i){
						$enabled = $1;
						$enabled =~ s/(No|False)/0/i;
						$enabled =~ s/(Yes|True)/1/i;
					}
					# print out the line if all 3 values are found, otherwise if a new
					# repoTitle is hit above, it will print out the line there instead
					if ($url && $title && defined $enabled){
						if ($enabled > 0){
 							push(@content, "$title ~ $url");
 						}
 						($enabled,$url,$title) = (0,'','');
					}
				}
				# print the last one if there is data for it
				if ($url && $title && $enabled){
					push(@content, "$title ~ $url");
				}
				if (!@content){
					$key = repo_data('missing',$repo);
				}
				else {
					clean_url(\@content);
					$key = repo_data('active',$repo);
				}
				push(@$rows, 
				{main::key($num++,1,1,$key) => $_},
				[@content],
				);
				@content = ();
			}
		}
		# print Data::Dumper::Dumper \@$rows;
	}
	# emerge, portage: Gentoo + derived
	if ((-d $portage_dir || -d $portage_gentoo_dir) && main::check_program('emerge')){
		@files = (main::globber("$portage_dir*.conf"),main::globber("$portage_gentoo_dir*.conf"));
		$repo = 'portage';
		if (@files){
			foreach (sort @files){
				@data2 = main::reader($_);
				push(@dbg_files, $_) if $debugger_dir;
				my ($enabled,$url,$title) = (undef,'','');
				foreach my $line (@data2){
					# this is a hack, assuming that each item has these fields listed, we collect the 3
					# items one by one, then when the url/enabled fields are set, we print it out and
					# reset the data. Not elegant but it works. Note that if enabled was not present
					# we assume it is enabled then, and print the line, reset the variables. This will
					# miss the last item, so it is printed if found in END
					if ($line =~ /^\[(.+)\]/){
						my $temp = $1;
						if ($url && $title && defined $enabled){
							if ($enabled > 0){
								push(@content, "$title ~ $url");
							}
							($enabled,$url,$title) = (undef,'','');
						}
						$title = $temp;
					}
					elsif ($line =~ /^(sync-uri)\s*=\s*(.*)/i){
						$url = $2;
					}
					# note: enabled = 1. enabled = 0 means disabled
					elsif ($line =~ /^auto-sync\s*=\s*(0|1|No|Yes|True|False)/i){
						$enabled = $1;
						$enabled =~ s/(No|False)/0/i;
						$enabled =~ s/(Yes|True)/1/i;
					}
					# print out the line if all 3 values are found, otherwise if a new
					# repoTitle is hit above, it will print out the line there instead
					if ($url && $title && defined $enabled){
						if ($enabled > 0){
 							push(@content, "$title ~ $url");
 						}
 						($enabled,$url,$title) = (undef,'','');
					}
				}
				# print the last one if there is data for it
				if ($url && $title && $enabled){
					push(@content, "$title ~ $url");
				}
				if (! @content){
					$key = repo_data('missing','portage');
				}
				else {
					clean_url(\@content);
					$key = repo_data('active','portage');
				}
				push(@$rows, 
				{main::key($num++,1,1,$key) => $_},
				[@content],
				);
				@content = ();
			}
		}
	}
	## apk: Alpine, Chimera
	if (-f $apk || -d "$apk.d"){
		@files = main::globber("$apk.d/*.list");
		push(@files, $apk);
		# prefilter list for logging
		@files = grep {-f $_} @files; # may not have $apk file.
		main::log_data('data',"apk repo files:\n" . main::joiner(\@files, "\n", 'unset')) if $b_log;
		foreach (sort @files){
			# -r to be on safe side
			if (-r $_){
				$data = repo_builder($_,'apk','^\s*[^#]+');
				push(@$rows,@$data);
			}
		}
	}
	## scratchpkg: Venom
	if (-f $scratchpkg){
		$data = repo_builder($scratchpkg,'scratchpkg','^[[:space:]]*[^#]+');
		push(@$rows,@$data);
	}
	# cards: Nutyx
	if (-f $cards){
		@data3 = main::reader($cards,'clean');
		push(@dbg_files, $cards) if $debugger_dir;
		foreach (@data3){
			if ($_ =~ /^dir\s+\/[^\|]+\/([^\/\|]+)\s*(\|\s*((http|ftp).*))?/){
				my $type = ($3) ? $3: 'local';
				push(@content, "$1 ~ $type");
			}
		}
		if (!@content){
			$key = repo_data('missing','cards');
		}
		else {
			clean_url(\@content);
			$key = repo_data('active','cards');
		}
		push(@$rows, 
		{main::key($num++,1,1,$key) => $cards},
		[@content],
		);
		@content = ();
	}
	## tazpkg: Slitaz
	if (-e $tazpkg || -e $tazpkg_mirror){
		$data = repo_builder($tazpkg_mirror,'tazpkg','^\s*[^#]+');
		push(@$rows,@$data);
	}
	## tce: TinyCore 
	if (-e $tce_app || -f $tce_file || -f $tce_file2){
		if (-f $tce_file){
			$data = repo_builder($tce_file,'tce','^\s*[^#]+');
			push(@$rows,@$data);
		}
		if (-f $tce_file2){
			$data = repo_builder($tce_file2,'tce','^\s*[^#]+');
			push(@$rows,@$data);
		}
	}
	## xbps: Void 
	if (-d $xbps_dir_1 || -d $xbps_dir_2){
		@files = main::globber("$xbps_dir_1*.conf");
		push(@files,main::globber("$xbps_dir_2*.conf")) if -d $xbps_dir_2;
		main::log_data('data',"xbps repo files:\n" . main::joiner(\@files, "\n", 'unset')) if $b_log;
		foreach (sort @files){
			if (-r $_){
				$data = repo_builder($_,'xbps','^\s*repository\s*=','\s*=\s*',1);
				push(@$rows,@$data);
			}
		}
	}
	## urpmq: Mandriva, Mageia
	if ($path = main::check_program('urpmq')){
		@data2 = main::grabber("$path --list-media active --list-url 2>/dev/null","\n",'strip');
		main::writer("$debugger_dir/system-repo-data-urpmq.txt",\@data2) if $debugger_dir;
		# Now we need to create the structure: repo info: repo path. We do that by 
		# looping through the lines of the output and then putting it back into the
		# <data>:<url> format print repos expects to see. Note this structure in the
		# data, so store first line and make start of line then when it's an http 
		# line, add it, and create the full line collection.
		# Contrib ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/2011/x86_64/media/contrib/release
		# Contrib Updates ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/2011/x86_64/media/contrib/updates
		# Non-free ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/2011/x86_64/media/non-free/release
		# Non-free Updates ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/2011/x86_64/media/non-free/updates
		# Nonfree Updates (Local19) /mnt/data/mirrors/mageia/distrib/cauldron/x86_64/media/nonfree/updates
		foreach (@data2){
			# Need to dump leading/trailing spaces and clear out color codes for irc output
			$_ =~ s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;
			$_ =~ s/\e\[([0-9];)?[0-9]+m//g;
			# urpmq output is the same each line, repo name space repo url, can be:
			# rsync://, ftp://, file://, http:// OR repo is locally mounted on FS in some cases
			if (/(.+)\s([\S]+:\/\/.+)/){
				# pack the repo url
				push(@content, $1);
				clean_url(\@content);
				# get the repo
				$repo = $2;
				push(@$rows, 
				{main::key($num++,1,1,'urpm repo') => $repo},
				[@content],
				);
				@content = ();
			}
		}
	}
	# pisi: Pardus, Solus
	if ((-d $pisi_dir && ($path = main::check_program('pisi'))) || 
	 (-d $eopkg_dir && ($path = main::check_program('eopkg')))){
		#$path = 'eopkg';
		my $which = ($path =~ /pisi$/) ? 'pisi': 'eopkg';
		my $cmd = ($which eq 'pisi') ? "$path list-repo": "$path lr";
		# my $file = "$ENV{HOME}/bin/scripts/inxi/data/repo/solus/eopkg-2.txt";
		# @data2 = main::reader($file,'strip');
		@data2 = main::grabber("$cmd 2>/dev/null","\n",'strip');
		main::writer("$debugger_dir/system-repo-data-$which.txt",\@data2) if $debugger_dir;
		# Now we need to create the structure: repo info: repo path
		# We do that by looping through the lines of the output and then putting it 
		# back into the <data>:<url> format print repos expects to see. Note this 
		# structure in the data, so store first line and make start of line then
		# when  it's an http line, add it, and create the full line collection.
		# Pardus-2009.1 [Aktiv]
		# 	http://packages.pardus.org.tr/pardus-2009.1/pisi-index.xml.bz2
		# Contrib [Aktiv]
		# 	http://packages.pardus.org.tr/contrib-2009/pisi-index.xml.bz2
		# Solus [inactive]
		# 	https://packages.solus-project.com/shannon/eopkg-index.xml.xz
		foreach (@data2){
			next if /^\s*$/;
			# need to dump leading/trailing spaces and clear out color codes for irc output
			$_ =~ s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;
			$_ =~ s/\e\[([0-9];)?[0-9]+m//g;
			if (/^\/|:\/\//){
				push(@content, $_) if $repo;
			}
			# Local [inactive] Unstable [active]
			elsif (/^(.*)\s\[([\S]+)\]/){
				$repo = $1;
				$repo = ($2 =~ /^activ/i) ? $repo : '';
			}
			if ($repo && @content){
				clean_url(\@content);
				$key = repo_data('active',$which);
				push(@$rows, 
				{main::key($num++,1,1,$key) => $repo},
				[@content],
				);
				$repo = '';
				@content = ();
			}
		}
		# last one if present
		if ($repo && @content){
			clean_url(\@content);
			$key = repo_data('active',$which);
			push(@$rows, 
			{main::key($num++,1,1,$key) => $repo},
			[@content],
			);
		}
	}
	## nix: General pm for Linux/Unix
	if (-f $nix && ($path = main::check_program('nix-channel'))){
		@content = main::grabber("$path --list 2>/dev/null","\n",'strip');
		main::writer("$debugger_dir/system-repo-data-nix.txt",\@content) if $debugger_dir;
		if (!@content){
			$key = repo_data('missing','nix');
		}
		else {
			clean_url(\@content);
			$key = repo_data('active','nix');
		}
		my $user = ($ENV{'USER'}) ? $ENV{'USER'}: 'N/A';
		push(@$rows, 
		{main::key($num++,1,1,$key) => $user},
		[@content],
		);
		@content = ();
		
	}
	# print Dumper $rows;
	eval $end if $b_log;
}

sub get_repos_bsd {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@content,$data,@data2,@data3,@files);
	my ($key);
	my $bsd_pkg = '/usr/local/etc/pkg/repos/';
	my $freebsd = '/etc/freebsd-update.conf';
	my $freebsd_pkg = '/etc/pkg/FreeBSD.conf';
	my $ghostbsd_pkg = '/etc/pkg/GhostBSD.conf';
	my $hardenedbsd_pkg = '/etc/pkg/HardenedBSD.conf';
	my $mports = '/usr/mports/Makefile';
	my $netbsd = '/usr/pkg/etc/pkgin/repositories.conf';
	my $openbsd = '/etc/pkg.conf';
	my $openbsd2 = '/etc/installurl';
	my $portsnap =  '/etc/portsnap.conf';
	if (-f $portsnap || -f $freebsd || -d $bsd_pkg || 
	 -f $ghostbsd_pkg || -f $hardenedbsd_pkg){
		if (-f $portsnap){
			$data = repo_builder($portsnap,'portsnap','^\s*SERVERNAME','\s*=\s*',1);
			push(@$rows,@$data);
		}
		if (-f $freebsd){
			$data = repo_builder($freebsd,'freebsd','^\s*ServerName','\s+',1);
			push(@$rows,@$data);
		}
		if (-d $bsd_pkg || -f $freebsd_pkg || -f $ghostbsd_pkg || -f $hardenedbsd_pkg){
			@files = main::globber('/usr/local/etc/pkg/repos/*.conf');
			push(@files, $freebsd_pkg) if -f $freebsd_pkg;
			push(@files, $ghostbsd_pkg) if -f $ghostbsd_pkg;
			push(@files, $hardenedbsd_pkg) if -f $hardenedbsd_pkg;
			if (@files){
				my ($url);
				foreach (@files){
					push(@dbg_files, $_) if $debugger_dir;
					# these will be result sets separated by an empty line
					# first dump all lines that start with #
					@content =  main::reader($_,'strip');
					# then do some clean up on the lines
					@content = map { $_ =~ s/{|}|,|\*//g; $_;} @content if @content;
					# get all rows not starting with a # and starting with a non space character
					my $url = '';
					foreach my $line (@content){
						if ($line !~ /^\s*$/){
							my @data2 = split(/\s*:\s*/, $line);
							@data2 = map { $_ =~ s/^\s+|\s+$//g; $_;} @data2;
							if ($data2[0] eq 'url'){
								$url = "$data2[1]:$data2[2]";
								$url =~ s/"|,//g;
							}
							# print "url:$url\n" if $url;
							if ($data2[0] eq 'enabled'){
								if ($url && $data2[1] =~ /^(1|true|yes)$/i){
									push(@data3, "$url");
								}
								$url = '';
							}
						}
					}
					if (!@data3){
						$key = repo_data('missing','bsd-package');
					}
					else {
						clean_url(\@data3);
						$key = repo_data('active','bsd-package');
					}
					push(@$rows, 
					{main::key($num++,1,1,$key) => $_},
					[@data3],
					);
					@data3 = ();
				}
			}
		}
	}
	if (-f $openbsd || -f $openbsd2){
		if (-f $openbsd){
			$data = repo_builder($openbsd,'openbsd','^installpath','\s*=\s*',1);
			push(@$rows,@$data);
		}
		if (-f $openbsd2){
			$data = repo_builder($openbsd2,'openbsd','^(http|ftp)','',1);
			push(@$rows,@$data);
		}
	}
	if (-f $netbsd){
		# not an empty row, and not a row starting with #
		$data = repo_builder($netbsd,'netbsd','^\s*[^#]+$');
		push(@$rows,@$data);
	}
	# I don't think this is right, have to find out, for midnightbsd
	# 	if (-f $mports){
	# 		@data = main::reader($mports,'strip');
	# 		main::writer("$debugger_dir/system-repo-data-mports.txt",\@data) if $debugger_dir;
	# 		for (@data){
	# 			if (!/^MASTER_SITE_INDEX/){
	# 				next;
	# 			}
	# 			else {
	# 				push(@data3,(split(/=\s*/,$_))[1]);
	# 			}
	# 			last if /^INDEX/;
	# 		}
	# 		if (!@data3){
	# 			$key = repo_data('missing','mports');
	# 		}
	# 		else {
	# 			clean_url(\@data3);
	# 			$key = repo_data('active','mports');
	# 		}
	# 		push(@$rows, 
	# 		{main::key($num++,1,1,$key) => $mports},
	# 		[@data3],
	# 		);
	# 		@data3 = ();
	# 	}
	# BSDs do not default always to having repo files, so show correct error 
	# mesage in that case
	if (!@$rows){
		if ($bsd_type eq 'freebsd'){
			$key = repo_data('missing','freebsd-files');
		}
		elsif ($bsd_type eq 'openbsd'){
			$key = repo_data('missing','openbsd-files');
		}
		elsif ($bsd_type eq 'netbsd'){
			$key = repo_data('missing','netbsd-files');
		}
		else {
			$key = repo_data('missing','bsd-files');
		}
		push(@$rows, 
		{main::key($num++,0,1,'Message') => $key},
		[()],
		);
	}
	eval $start if $b_log;
}

sub set_repo_keys {
	eval $start if $b_log;
	%repo_keys = (
	'apk-active' => 'APK repo',
	'apk-missing' => 'No active APK repos in',
	'apt-active' => 'Active apt repos in',
	'apt-missing' => 'No active apt repos in',
	'bsd-files-missing' => 'No pkg server files found',
	'bsd-package-active' => 'Enabled pkg servers in',
	'bsd-package-missing' => 'No enabled BSD pkg servers in',
	'cards-active' => 'Active CARDS collections in',
	'cards-missing' => 'No active CARDS collections in',
	'dnf-active' => 'Active dnf repos in',
	'dnf-missing' => 'No active dnf repos in',
	'eopkg-active' => 'Active eopkg repo',
	'eopkg-missing' => 'No active eopkg repos found',
	'files-missing' => 'No repo files found in',
	'freebsd-active' => 'FreeBSD update server',
	'freebsd-files-missing' => 'No FreeBSD update server files found',
	'freebsd-missing' => 'No FreeBSD update servers in',
	'freebsd-pkg-active' => 'FreeBSD default pkg server',
	'freebsd-pkg-missing' => 'No FreeBSD default pkg server in',
	'mports-active' => 'mports servers',
	'mports-missing' => 'No mports servers found',
	'netbsd-active' => 'NetBSD pkg servers',
	'netbsd-files-missing' => 'No NetBSD pkg server files found',
	'netbsd-missing' => 'No NetBSD pkg servers in',
	'netpkg-active' => 'Active netpkg repos in',
	'netpkg-missing' => 'No active netpkg repos in',
	'nix-active' => 'Active nix channels for user',
	'nix-missing' => 'No nix channels found for user',
	'openbsd-active' => 'OpenBSD pkg mirror',
	'openbsd-files-missing' => 'No OpenBSD pkg mirror files found',
	'openbsd-missing' => 'No OpenBSD pkg mirrors in',
	'pacman-active' => 'Active pacman repo servers in',
	'pacman-missing' => 'No active pacman repos in',
	'pacman-g2-active' => 'Active pacman-g2 repo servers in',
	'pacman-g2-missing' => 'No active pacman-g2 repos in',
	'pisi-active' => 'Active pisi repo',
	'pisi-missing' => 'No active pisi repos found',
	'portage-active' => 'Enabled portage sources in',
	'portage-missing' => 'No enabled portage sources in',
	'portsnap-active' => 'Ports server',
	'portsnap-missing' => 'No ports servers in',
	'sbopkg-active' => 'Active sbopkg repo',
	'sbopkg-active-permissions' => 'Active sbopkg repo (confirm with root)',
	'sbopkg-missing' => 'No sbopkg repo',
	'sboui-active' => 'Active sboui repo',
	'sboui-missing' => 'No sboui repo',
	'scratchpkg-active' => 'scratchpkg repos in',
	'scratchpkg-missing' => 'No active scratchpkg repos in',
	'slackpkg-active' => 'slackpkg mirror in',
	'slackpkg-missing' => 'No slackpkg mirror set in',
	'slackpkg+-active' => 'slackpkg+ repos in',
	'slackpkg+-missing' => 'No active slackpkg+ repos in',
	'slaptget-active' => 'slapt-get repos in',
	'slaptget-missing' => 'No active slapt-get repos in',
	'slpkg-active' => 'Active slpkg repos in',
	'slpkg-missing' => 'No active slpkg repos in',
	'tazpkg-active' => 'tazpkg mirrors in',
	'tazpkg-missing' => 'No tazpkg mirrors in',
	'tce-active' => 'tce mirrors in',
	'tce-missing' => 'No tce mirrors in',
	'xbps-active' => 'Active xbps repos in',
	'xbps-missing' => 'No active xbps repos in',
	'yum-active' => 'Active yum repos in',
	'yum-missing' => 'No active yum repos in',
	'zypp-active' => 'Active zypp repos in',
	'zypp-missing' => 'No active zypp repos in',
	);
	eval $end if $b_log;
}

sub repo_data {
	eval $start if $b_log;
	my ($status,$type) = @_;
	set_repo_keys() if !%repo_keys;
	eval $end if $b_log;
	return $repo_keys{$type . '-' . $status};
}

sub repo_builder {
	eval $start if $b_log;
	my ($file,$type,$search,$split,$count) = @_;
	my (@content,$key);
	push(@dbg_files, $file) if $debugger_dir;
	if (-r $file){
		@content =  main::reader($file);
		@content = grep {/$search/i && !/^\s*$/} @content if @content;
		clean_data(\@content) if @content;
	}
	if ($split && @content){
		@content = map { 
		my @inner = split(/$split/, $_);
		$inner[$count];
		} @content;
	}
	if (!@content){
		$key = repo_data('missing',$type);
	}
	else {
		$key = repo_data('active',$type);
		clean_url(\@content);
	}
	eval $end if $b_log;
	return [
	{main::key($num++,1,1,$key) => $file},
	[@content],
	];
}

sub clean_data {
	# basics: trim white space, get rid of double spaces; trim comments at 
	# ends of repo values
	@{$_[0]} = map {
	$_ =~ s/\s\s+/ /g;
	$_ =~ s/^\s+|\s+$//g;
	$_ =~ s/\[\s+/[/g; # [ signed-by
	$_ =~ s/\s+\]/]/g;
	$_ =~ s/^(.*\/.*) #.*/$1/; 
	$_;} @{$_[0]};
}

# Clean if irc
sub clean_url {
	@{$_[0]} = map {$_ =~ s/:\//: \//; $_} @{$_[0]} if $b_irc;
	# trim comments at ends of repo values
	@{$_[0]} = map {$_ =~ s/^(.*\/.*) #.*/$1/; $_} @{$_[0]};
}

sub file_path {
	my ($filename,$dir) = @_;
	my ($working);
	$working = $filename;
	$working =~ s/^\///;
	$working =~ s/\//-/g;
	$working = "$dir/file-repo-$working.txt";
	return $working;
}
}

## SensorItem
{
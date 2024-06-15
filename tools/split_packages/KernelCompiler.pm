package KernelCompiler;

sub get {
	eval $start if $b_log;
	my $compiler = []; # we want an array ref to return if not set
	if (my $file = $system_files{'proc-version'}){
		version_proc($compiler,$file);
	}
	elsif ($bsd_type){
		version_bsd($compiler);
	}
	eval $end if $b_log;
	return $compiler;
}

# args: 0: compiler by ref
sub version_bsd {
	eval $start if $b_log;
	my $compiler = $_[0];
	if ($alerts{'sysctl'}->{'action'} && $alerts{'sysctl'}->{'action'} eq 'use'){
		if ($sysctl{'kernel'}){
			my @working;
			foreach (@{$sysctl{'kernel'}}){
				# Not every line will have a : separator though the processor should make 
				# most have it. This appears to be 10.x late feature add, I don't see it
				# on earlier BSDs
				if (/^kern.compiler_version/){
					@working = split(/:\s*/, $_);
					$working[1] =~ /.*(clang|gcc|zigcc)\sversion\s([\S]+)\s.*/;
					@$compiler = ($1,$2);
					last;
				}
			}
		}
		# OpenBSD doesn't show compiler data in sysctl or dboot but it's going to
		# be Clang until way into the future, and it will be the installed version.
		if (ref $compiler ne 'ARRAY' || !@$compiler){
			if (my $path = main::check_program('clang')){
				($compiler->[0],$compiler->[1]) = ProgramData::full('clang',$path);
			}
		}
	}
	main::log_data('dump','@$compiler',$compiler) if $b_log;
	eval $end if $b_log;
}

# args: 0: compiler by ref; 1: proc file name
sub version_proc {
	eval $start if $b_log;
	my ($compiler,$file) = @_;
	if (my $result = main::reader($file,'',0)){
		my $version;
		if ($fake{'compiler'}){
			# $result = $result =~ /\*(gcc|clang)\*eval\*/;
			# $result='Linux version 5.4.0-rc1 (sourav@archlinux-pc) (clang version 9.0.0 (tags/RELEASE_900/final)) #1 SMP PREEMPT Sun Oct 6 18:02:41 IST 2019';
			# $result='Linux version 5.8.3-fw1 (fst@x86_64.frugalware.org) ( OpenMandriva 11.0.0-0.20200819.1 clang version 11.0.0 (/builddir/build/BUILD/llvm-project-release-11.x/clang 2a0076812cf106fcc34376d9d967dc5f2847693a), LLD 11.0.0)';
			# $result='Linux version 5.8.0-18-generic (buildd@lgw01-amd64-057) (gcc (Ubuntu 10.2.0-5ubuntu2) 10.2.0, GNU ld (GNU Binutils for Ubuntu) 2.35) #19-Ubuntu SMP Wed Aug 26 15:26:32 UTC 2020';
			# $result='Linux version 5.8.9-fw1 (fst@x86_64.frugalware.org) (gcc (Frugalware Linux) 9.2.1 20200215, GNU ld (GNU Binutils) 2.35) #1 SMP PREEMPT Tue Sep 15 16:38:57 CEST 2020';
			# $result='Linux version 5.8.0-2-amd64 (debian-kernel@lists.debian.org) (gcc-10 (Debian 10.2.0-9) 10.2.0, GNU ld (GNU Binutils for Debian) 2.35) #1 SMP Debian 5.8.10-1 (2020-09-19)';
			# $result='Linux version 5.9.0-5-amd64 (debian-kernel@lists.debian.org) (gcc-10 (Debian 10.2.1-1) 10.2.1 20201207, GNU ld (GNU Binutils for Debian) 2.35.1) #1 SMP Debian 5.9.15-1 (2020-12-17)';
			# $result='Linux version 2.6.1 (GNU 0.9 GNU-Mach 1.8+git20201007-486/Hurd-0.9 i686-AT386)';
			# $result='NetBSD version 9.1 (netbsd@localhost) (gcc version 7.5.0) NetBSD 9.1 (GENERIC) #0: Sun Oct 18 19:24:30 UTC 2020';
			 #$result='Linux version 6.0.8-0-generic (chimera@chimera) (clang version 15.0.4, LLD 15.0.4) #1 SMP PREEMPT_DYNAMIC Fri Nov 11 13:45:29 UTC 2022';
			# 2023 ubuntu, sigh..
			# $result='Linux version 6.5.8-1-liquorix-amd64 (steven@liquorix.net) (gcc (Debian 13.2.0-4) 13.2.0, GNU ld (GNU Binutils for Debian) 2.41) #1 ZEN SMP PREEMPT liquorix 6.5-9.1~trixie (2023-10-19)';
			# $result='Linux version 6.5.0-9-generic (buildd@bos03-amd64-043) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-4ubuntu3) 13.2.0, GNU ld (GNU Binutils for Ubuntu) 2.41) #9-Ubuntu SMP PREEMPT_DYNAMIC Sat Oct  7 01:35:40 UTC 2023';
			# $result='Linux version 6.5.13-un-def-alt1 (builder@localhost.localdomain) (gcc-13 (GCC) 13.2.1 20230817 (ALT Sisyphus 13.2.1-alt2), GNU ld (GNU Binutils) 2.41.0.20230826) #1 SMP PREEMPT_DYNAMIC Wed Nov 29 15:54:38 UTC 2023';
		}
		# Note: zigcc is only theoretical, but someone is going to try it!
		# cleanest, old style: 'clang version 9.0.0 (' | 'gcc version 7.5.0'
		if ($result =~ /(gcc|clang|zigcc).*?version\s([^,\s\)]+)/){
			@$compiler = ($1,$2);
		}
		# new styles: compiler + stuff + x.y.z. Ignores modifiers to number: -4, -ubuntu
		elsif ($result =~ /(gcc|clang|zigcc).*?\s(\d+(\.\d+){2,4})[)\s,_-]/){
			@$compiler = ($1,$2);
		}
		# failed, let's at least try for compiler type
		elsif ($result =~ /(gcc|clang|zigcc)/){
			@$compiler = ($1,'N/A');
		}
	}
	main::log_data('dump','@$compiler',$compiler) if $b_log;
	eval $end if $b_log;
}
}

sub get_kernel_data {
	eval $start if $b_log;
	my ($ksplice) = ('');
	my $kernel = [];
	# Linux; yawn; 4.9.0-3.1-liquorix-686-pae; #1 ZEN SMP PREEMPT liquorix 4.9-4 (2017-01-14); i686
	# FreeBSD; siwi.pair.com; 8.2-STABLE; FreeBSD 8.2-STABLE #0: Tue May 31 14:36:14 EDT 2016     erik5@iddhi.pair.com:/usr/obj/usr/src/sys/82PAIRx-AMD64; amd64
	if (@uname){
		$kernel->[0] = $uname[2];
		if ((my $program = check_program('uptrack-uname')) && $kernel->[0]){
			$ksplice = qx($program -rm);
			$ksplice = trimmer($ksplice);
			$kernel->[0] = $ksplice . ' (ksplice)' if $ksplice;
		}
		$kernel->[1] = $uname[-1];
	}
	# we want these to have values to save validation checks for output
	$kernel->[0] ||= 'N/A';
	$kernel->[1] ||= 'N/A';
	log_data('data',"kernel: " . join('; ', $kernel) . " ksplice: $ksplice") if $b_log;
	log_data('dump','perl @uname', \@uname) if $b_log;
	eval $end if $b_log;
	return $kernel;
}

## KernelParameters
{
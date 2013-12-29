# Cross-compiling from Linux to mingw64

# cd to win32 and run Configure as ../Configure -Dmksymlinks ...

osname="MSWin32"

usethreads="$define"
useithreads="$define"
useshrplib="$define"


ccflags="$ccflags -MD -DWIN32 -DPERL_IMPLICIT_CONTEXT -DPERL_IMPLICIT_SYS -DPERLDLL -DPERL_TEXTMODE_SCRIPTS"
ccflags="$ccflags -fno-strict-aliasing -mms-bitfields -fpermissive"
ccflags="$ccflags -I$src -I$src/win32 -I$src/win32/include "
cppflags="$cppflags $ccflags"
libswanted='net socket inet nsl nm ndbm gdbm dbm db malloc dl ld sun m c cposix posix ndir dir crypt ucb bsd BSD PW x msvcrt ws2_32 wsock32 comctl32 mingw32 mingw64'

lddlflags="$lddlflags -mdll"
dlext='dll'
so='dll'
dlsrc='dl_win32.xs'
mallocobj='malloc.o'
mallocsrc='malloc.c'

ld="$cc"

dlltool='dlltool.exe'

#usenm="$undef"

archobjs="win32.o win32sck.o win32thread.o fcrypt.o win32io.o"


d_gethbyaddr='define'
d_gethbyname='define'
d_gethname='define'
d_gethostprotos='define'
d_getlogin='define'
d_getpbyname='define'
d_getpbynumber='define'
d_getprotoprotos='define'
d_getsbyname='define'
d_getsbyport='define'
d_getservprotos='define'

# These are defined in msvcrt.a but we don't have wrappers for them
d_inetntop='undef'
d_inetpton='undef'

# WIP

_exe='.exe'

# Why isn't Configure finding the proper values here?
d_dlerror='define'
d_dlopen='define'

clocktype='clock_t'
db_hashtype='int'
db_prefixtype='int'
groupstype='gid_t'
i8type='char'
lseektype='long'
netdb_hlen_type='int'
netdb_host_type='char *'
netdb_name_type='char *'
pidtype='int'
selecttype='Perl_fd_set *'
shmattype='void *'
ssizetype='int'
uidtype='uid_t'

gidformat='"ld"'
gidsign='-1'
gidsize='4'
gidtype='gid_t'

# /WIP

# This script UU/archname.cbu will get 'called-back' by Configure.
$cat > UU/archname.cbu <<'EOCBU'
# Configure lowercases osname after the hints files
# are run, so we work around it here.
osname="MSWin32"
EOCBU

case "$src" in
    /*)
            unix_to_dos=$src/Cross/unix_to_dos
            run_ssh_bat=$src/Cross/run-ssh.bat
            cp $src/win32/*.[ch] $src/
            cp $src/win32/FindExt.pm $src/lib/
            mkdir $src/lib/CORE/
            cp $src/*.h $src/lib/CORE/
            cp -pR $src/win32/include/* $src/lib/CORE/
            ;;
    *)  pwd=`test -f ../Configure && cd ..; pwd`
            unix_to_dos=$pwd/Cross/unix_to_dos
            run_ssh_bat=$pwd/Cross/run-ssh.bat
            cp $pwd/win32/*.[ch] $pwd/
            cp $pwd/win32/FindExt.pm $pwd/lib/
            mkdir $pwd/lib/CORE/
            cp $pwd/*.h $pwd/lib/CORE/
            cp -pR $pwd/win32/include/* $pwd/lib/CORE/
            ;;
esac

cat >$unix_to_dos <<EOF
#!/bin/sh
echo \$@ | $tr '/' '\\\\'
EOF
$chmod a+rx $unix_to_dos

cat >$run <<EOF
#!/bin/sh
env=''
case "\$1" in
-cwd)
  shift
  cwd=\$1
  shift
  ;;
esac
case "\$1" in
-env)
  shift
  env=\$1
  shift
  ;;
esac
case "\$cwd" in
'') cwd=$targetdir ;;
esac
exe=\$1
shift

if $test ! -e \$exe -a -e "\$exe.exe"; then
    exe="\$exe.exe"
fi

$to \$exe

exe=\`$unix_to_dos \$exe\`
cwd=\`$unix_to_dos \$cwd\`

$targetrun -p $targetport -l $targetuser $targethost "cd \$cwd && .\run-ssh.bat \$env \$exe \$@" | $tr -d '\r'

$from output.status 2>/dev/null
if $test -e output.status; then
    result_status=\`$cat output.status\`
    result_status=\`echo \$result_status | $tr -d '\r'\`
    rm output.status
else
    result_status=0
fi

exit \$result_status
EOF
$chmod a+rx $run

cat >$targetmkdir <<EOF
#!/bin/sh
$targetrun -p $targetport -l $targetuser $targethost "mkdir \$@"
EOF
$chmod a+rx $targetmkdir

cat >$to <<EOF
#!/bin/sh
for f in \$@
do
  case "\$f" in
  *)
    if $test ! -e \$f -a -e "\$f.exe"; then
        f="\$f.exe"
    fi
    case \$f in
        ./*)
            nostart=\`echo \$f | sed 's:^..::'\`
            winname=\`$unix_to_dos $targetdir/\$nostart\`
            ;;
        *)
            winname=\`$unix_to_dos $targetdir/\$f\`
            dirname=\`dirname \$f\`
            $targetmkdir \`$unix_to_dos $targetdir/$dirname\` 2>/dev/null
            ;;
    esac
    $targetto -P $targetport -r $q \$f $targetuser@$targethost:\$winname  2>/dev/null || exit 1
    ;;
  esac
done
exit 0
EOF
$chmod a+rx $to

cat >run-ssh.bat <<EOF
@echo off
setlocal ENABLEDELAYEDEXPANSION
call %*
echo %ERRORLEVEL% > output.status
endlocal
EOF
$chmod a+rx run-ssh.bat
$to run-ssh.bat 2>/dev/null

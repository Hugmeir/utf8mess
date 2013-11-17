# Cross-compiling from Linux to mingw64

# cd to win32 and run Configure as ../Configure -Dmksymlinks ...

osname=MSWin32

usethreads='define'
useithreads='define'

ccflags="$ccflags -MD -DWIN32 -DPERL_IMPLICIT_CONTEXT -DPERL_IMPLICIT_SYS -DPERLDLL -DPERL_TEXTMODE_SCRIPTS -fno-strict-aliasing -mms-bitfields -fpermissive"
cppflags="$cppflags -DWIN32"
libswanted='net socket inet nsl nm ndbm gdbm dbm db malloc dl ld sun m c cposix posix ndir dir crypt ucb bsd BSD PW x'

lddlflags="$lddlflags -mdll"
dlext='dll'
so='dll'
dlsrc='dl_win32.xs'

usenm="$undef"

ccflags="$ccflags -I$src/win32 -I$src/win32/include "

case "$src" in
    /*) run=$src/Cross/run
            unix_to_dos=$src/Cross/unix_to_dos
            dos_to_unix=$src/Cross/dos_to_unix
            run_ssh_bat=$src/Cross/run-ssh.bat
            ;;
    *)  pwd=`test -f ../Configure && cd ..; pwd`
            unix_to_dos=$pwd/Cross/unix_to_dos
            dos_to_unix=$pwd/Cross/dos_to_unix
            run_ssh_bat=$pwd/Cross/run-ssh.bat
            ;;
esac

cat >$unix_to_dos <<EOF
#!/bin/sh
echo \$@ | $tr '/' '\\\\'
EOF
$chmod a+rx $unix_to_dos

cat >$dos_to_unix <<EOF
#!/bin/sh
f="\$@"
case "\$f" in
*[a-z]:\\\\*)
    f=\`echo \$f | $sed 's!.:.!/!'\`
    echo \$f | $tr '\\\\' '/'
    ;;
*) echo \$f | $tr '\\\\' '/'
    ;;
esac
EOF
$chmod a+rx $dos_to_unix

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

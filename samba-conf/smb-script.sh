user="wsUser1"
pass="testi123"

printf "$pass\n$pass\n" | smbpasswd -a -s $user

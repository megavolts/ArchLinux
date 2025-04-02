
# Backup current variable
yay -S efitools
for var in PK KEK db dbx ; do efi-readvar -v $var -o old_${var}.esl ; done


script_path=$(cd $(dirname ${0}); pwd) 

echo ${script_path}

rm -f ${script_path}/bak/*
cp -p ${script_path}/data/wordpress/wp-content/updraft/backup* ${script_path}/bak/

git add .
git commit -m "backup files"
git push origin master
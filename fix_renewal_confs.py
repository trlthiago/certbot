import sys
import glob
import os
import re
from datetime import datetime
import shutil, errno

def renewal_conf_files(renewal_configs_dir):
	return glob.glob(os.path.join(renewal_configs_dir, "*.conf"))

def Persist(renewal_file, content):
	if content:
		with open(renewal_file, "w") as f:
			f.write(content)
			f.close()
			print("Written successfully.")
	else:
		f.close()
		print("The content is Empty. Not saving!")

def MakeBackup():
	backupfolder = "/etc/letsencrypt/renewal_" + datetime.now().strftime('%Y-%m-%d_%H:%M:%S')
	#os.makedirs(backupfolder, 0o0755)
	shutil.copytree("/etc/letsencrypt/renewal", backupfolder)

def main(cli_args=sys.argv[1:]):
	dry = False
	if "dry" in cli_args:
		print("DRY")
		dry = True
	else: print("NOT DRY")

	MakeBackup()
	
	conf_files = renewal_conf_files("/etc/letsencrypt/renewal")
	parse_failures = []

	for renewal_file in conf_files:
		try:
			content = ""
			with open(renewal_file, "r") as f:
				content = f.read()
				f.close()

				domain = re.search("\[\[webroot_map\]\][\n](.*?)\s", content, re.MULTILINE).group(1)

				if not domain:
					raise Exception('Cannot find domain of ' + renewal_file)
				if (domain.startswith("www.")):
					domain = domain.replace("www.", "")

				pre = '\'[ -e "/home/' + domain + '/public/.htaccess" ] && (mv /home/' + domain + '/public/.htaccess /home/' + domain + '/public/.htaccess.umbler 2>> /etc/letsencrypt/trl.log) || echo "ok"\''

				post = '\'[ -e "/home/' + domain + '/public/.htaccess.umbler" ] && (mv /home/' + domain + '/public/.htaccess.umbler /home/' + domain + '/public/.htaccess 2>> /etc/letsencrypt/trl.log) || echo "ok"; sudo cp "$(sudo realpath /etc/letsencrypt/live/' + domain + '/cert.pem)" "$(sudo realpath /etc/letsencrypt/live/' + domain + '/cert.pem)-bkp-$(date +%y-%m-%d_%H:%M:%S)" && sudo cat "$(sudo realpath /etc/letsencrypt/live/' + domain + '/privkey.pem)" >> "$(sudo realpath /etc/letsencrypt/live/' + domain + '/cert.pem)"\''
				
				content = re.sub("version\s\=\s[\.0-9]*", "version = 0.10.1", content)
				content = re.sub("pre_hook\s\=\s.*[\r\n]*", "", content)
				content = re.sub("post_hook\s\=\s.*[\r\n]*", "", content)
				content = re.sub("renew_hook\s\=\s.*[\r\n]*", "", content)
				content = content.replace('[renewalparams]', '[renewalparams]\npre_hook = %s\npost_hook = %s' % (pre, post))
				
			print(content)
			if not dry:
				Persist(renewal_file, content)
			else: print("DRY")
		except Exception as e:
			print(e)
			parse_failures.append(renewal_file)
	PrintFaileds(parse_failures)

def PrintFaileds(parse_failures):
	if (isinstance(parse_failures,list) and len(parse_failures) > 0):
		print("The following domains failed to renew your certificates:\n")
		for target_list in parse_failures:
			print(target_list)

if __name__ == "__main__":
    err_string = main()


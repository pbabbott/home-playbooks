import sys

# print("Hello from custom.py")  # Stdout only printed when Failed
# try:
#     1 / 0
# except Exception as e:
#     sys.exit(e)

def main() -> int:
    filename = './vault.yml'
    result = 0

    with open(filename, encoding='UTF-8') as f:
        line1 = f.readline()
        if "ANSIBLE_VAULT" not in line1:
            print ("Ansible vault.yml is not encrypted. Preventing commit.")
            result =1

    return result


if __name__ == '__main__':
    raise SystemExit(main())

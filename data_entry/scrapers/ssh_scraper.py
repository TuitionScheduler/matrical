import telnetlib

HOST = "rumad.uprm.edu"
PORT = 22  # Default Telnet port

def main():
    try:
        # Connect to the Telnet server
        tn = telnetlib.Telnet(HOST, PORT)
        
        # Read until you get the login prompt
        tn.read_until(b"login")
        
        # Send the username
        tn.write(b"estudiante\n")
        
        # Read until you get the password prompt
        tn.read_until(b"password")
        
        # Send the password (assuming it's an empty password)
        tn.write(b"\n")
        
        tn.read_until(b"UNIVERSIDAD DE PUERTO RICO")

        print(tn.read_all().decode('ascii'))  # Print the output
        
        # Close the connection
        tn.close()
        
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()

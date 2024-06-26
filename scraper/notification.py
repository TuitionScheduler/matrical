import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase Admin SDK with your credentials
# cred = credentials.Certificate("miuni-c05d9-firebase-adminsdk-x9b3r-e7fad60c84.json")
# firebase_admin.initialize_app(cred)

def send_notification(title, body, token=None):
    # Construct the message
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )

    # Send the message
    response = messaging.send(message)
    print("Successfully sent message:", response)

# Example usage
# if __name__ == "__main__":
#     # FCM token of the device you want to send the message to
#     registration_token = "cj-4IWumRC6_kBHGGAAO3A:APA91bEyArelBVX-wdJg3VYiKbsJCYxZvR7Qot-C9YArz847YqYyyr3Izeb0NgxVX3LJNv8qx8I15v77ZZOgAgUXv8lZhhSk_aV72XydI9L4r_WdCI8hQns7wOHCMIFuLFpZguMf2LSR"

#     # Title and body of the notification
#     notification_title = "Test notification #3"
#     notification_body = "Yippee"

#     # Send the notification
#     send_notification(notification_title, notification_body, registration_token)

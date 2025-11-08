"""
Firebase Cloud Messaging (FCM) service for sending push notifications.
Uses FCM v1 API via firebase-admin SDK.
"""

import logging
from typing import Optional

import firebase_admin
from app.core.config import settings
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK (singleton)
_firebase_app = None


def initialize_firebase():
    """
    Initialize Firebase Admin SDK with service account credentials.
    This should be called once at application startup.
    """
    global _firebase_app

    if _firebase_app is not None:
        logger.info("Firebase Admin SDK already initialized")
        return

    try:
        # Check if already initialized (in case of multiple workers)
        if firebase_admin._apps:
            _firebase_app = firebase_admin.get_app()
            logger.info("Using existing Firebase Admin SDK instance")
            return

        # Initialize with service account credentials
        if settings.google_application_credentials:
            cred = credentials.Certificate(settings.google_application_credentials)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info(
                "Firebase Admin SDK initialized successfully with credentials file"
            )
        else:
            # Use default credentials (for Cloud Run with service account)
            _firebase_app = firebase_admin.initialize_app()
            logger.info("Firebase Admin SDK initialized with default credentials")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        raise


async def send_notification(
    token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Send a push notification to a specific device using FCM v1 API.

    Args:
        token: FCM device token
        title: Notification title
        body: Notification body text
        data: Optional data payload (key-value pairs)

    Returns:
        True if sent successfully, False otherwise
    """
    if not token:
        logger.warning("Cannot send notification: token is empty")
        return False

    try:
        # Construct the message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="high",
                ),
            ),
            apns=messaging.APNSConfig(
                headers={
                    "apns-priority": "10",
                },
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                    ),
                ),
            ),
        )

        # Send the message
        response = messaging.send(message)
        logger.info(
            f"Successfully sent notification to token {token[:20]}...: {response}"
        )
        return True

    except messaging.UnregisteredError:
        logger.warning(f"FCM token is unregistered or invalid: {token[:20]}...")
        return False
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
        return False


async def send_image_accepted_notification(
    token: str,
    category: int,
    weight: float,
    points_earned: int = 250,
) -> bool:
    """
    Send notification when an uploaded image is accepted.

    Args:
        token: FCM device token
        category: Trash category (1-4)
        weight: Trash weight (0.25-1.0)
        points_earned: Points earned (default 250)

    Returns:
        True if sent successfully, False otherwise
    """
    category_names = {
        1: "Light Litter",
        2: "Moderate Trash",
        3: "Heavy Debris",
        4: "Severe Pollution",
    }

    category_name = category_names.get(category, f"Category {category}")

    title = "Image Accepted!"
    body = f"You earned {points_earned} points! Category: {category_name}"

    data = {
        "type": "image_accepted",
        "category": str(category),
        "weight": str(weight),
        "points_earned": str(points_earned),
    }

    return await send_notification(token, title, body, data)


async def send_image_rejected_notification(
    token: str,
    reason: str = "Image doesn't meet quality standards",
) -> bool:
    """
    Send notification when an uploaded image is rejected.

    Args:
        token: FCM device token
        reason: Rejection reason (default message)

    Returns:
        True if sent successfully, False otherwise
    """
    title = "Image Rejected"
    body = f"{reason}. Please try again with a clearer trash photo."

    data = {
        "type": "image_rejected",
        "reason": reason,
    }

    return await send_notification(token, title, body, data)

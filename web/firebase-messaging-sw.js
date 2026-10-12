importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBoJXSXPgBNpcrCLRzwi1kazKFIU0GCYEE",
  authDomain: "serviprox-fa9bb.firebaseapp.com",
  projectId: "serviprox-fa9bb",
  storageBucket: "serviprox-fa9bb.appspot.com",
  messagingSenderId: "879591651485",
  appId: "1:879591651485:web:af01282e02a61a526f7c74"
});

const messaging = firebase.messaging();

// ← Notifications en arrière-plan
messaging.onBackgroundMessage((payload) => {
  console.log("Notification arrière-plan:", payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png"
  };

  self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});

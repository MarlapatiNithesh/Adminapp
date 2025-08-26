// File: controllers/notificationsController.js
const { db } = require('../config/firebase');

const getAllNotifications = async (req, res) => {
  try {
    const snapshot = await db.collection('farmer_notifications').get();
    const notifications = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const addNotification = async (req, res) => {
  try {
    const notification = req.body;
    const docRef = await db.collection('farmer_notifications').add(notification);
    res.status(201).json({ id: docRef.id, ...notification });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getAllNotifications, addNotification };

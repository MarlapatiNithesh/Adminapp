// File: controllers/servicesController.js
const { db } = require('../config/firebase');

const getAllServices = async (req, res) => {
  try {
    const snapshot = await db.collection('services').get();
    const services = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.status(200).json(services);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const addService = async (req, res) => {
  try {
    const newService = req.body;
    const docRef = await db.collection('services').add(newService);
    res.status(201).json({ id: docRef.id, ...newService });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const deleteService = async (req, res) => {
  try {
    const serviceId = req.params.id;
    await db.collection('services').doc(serviceId).delete();
    res.status(200).json({ message: 'Service deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getAllServices, addService, deleteService };

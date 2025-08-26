const { db } = require('../config/firebase');

const getAllBookings = async (req, res) => {
  try {
    const snapshot = await db.collection('bookings').get();
    const bookings = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.status(200).json(bookings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateBookingStatus = async (req, res) => {
  try {
    const bookingId = req.params.id;
    const { status } = req.body;
    if (!status) return res.status(400).json({ message: 'Status is required' });

    await db.collection('bookings').doc(bookingId).update({ status });
    res.status(200).json({ message: 'Booking status updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const getBookingById = async (req, res) => {
  try {
    const bookingId = req.params.id;
    const doc = await db.collection('bookings').doc(bookingId).get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    res.status(200).json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getAllBookings, updateBookingStatus, getBookingById };

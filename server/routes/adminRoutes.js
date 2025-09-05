const express = require('express');
const router = express.Router();

const auth = require('../middlewares/authMiddleware');
const { checkRole } = require('../utils/roleChecker');

const bookingsController = require('../controllers/bookingsController');
const servicesController = require('../controllers/servicesController');
const usersController = require('../controllers/usersController');
const notificationsController = require('../controllers/notificationsController');

// Bookings
router.get('/bookings',bookingsController.getAllBookings);
router.get('/bookings/:id', auth, checkRole('admin'), bookingsController.getBookingById);
router.patch('/bookings/:id/status', auth, checkRole('admin'), bookingsController.updateBookingStatus);

// Services
router.get('/services', auth, checkRole('admin'), servicesController.getAllServices);
router.post('/services', auth, checkRole('admin'), servicesController.addService);
router.delete('/services/:id', auth, checkRole('admin'), servicesController.deleteService);

// Users
router.get('/users', auth, checkRole('admin'), usersController.getAllUsers);
router.delete('/users/:id', auth, checkRole('admin'), usersController.deleteUser);
router.patch('/users/:id', auth, checkRole('admin'), usersController.updateUser);

// Notifications
router.get('/notifications', auth, checkRole('admin'), notificationsController.getAllNotifications);
router.post('/notifications', auth, checkRole('admin'), notificationsController.addNotification);

module.exports = router;

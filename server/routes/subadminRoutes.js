const express = require('express');
const router = express.Router();

const auth = require('../middlewares/authMiddleware');
const { checkRole } = require('../utils/roleChecker');

const bookingsController = require('../controllers/bookingsController');
const servicesController = require('../controllers/servicesController');
const usersController = require('../controllers/usersController');
const notificationsController = require('../controllers/notificationsController');

// Bookings
router.get('/bookings', auth, checkRole('subadmin'), bookingsController.getAllBookings);
router.get('/bookings/:id', auth, checkRole('subadmin'), bookingsController.getBookingById);
router.patch('/bookings/:id/status', auth, checkRole('subadmin'), bookingsController.updateBookingStatus);

// Services
router.get('/services', auth, checkRole('subadmin'), servicesController.getAllServices);
router.post('/services', auth, checkRole('subadmin'), servicesController.addService);
router.delete('/services/:id', auth, checkRole('subadmin'), servicesController.deleteService);

// Users
router.get('/users', auth, checkRole('subadmin'), usersController.getAllUsers);
router.delete('/users/:id', auth, checkRole('subadmin'), usersController.deleteUser);
router.patch('/users/:id', auth, checkRole('subadmin'), usersController.updateUser);

// Notifications
router.get('/notifications', auth, checkRole('subadmin'), notificationsController.getAllNotifications);
router.post('/notifications', auth, checkRole('subadmin'), notificationsController.addNotification);

module.exports = router;

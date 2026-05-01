import '../../../../core/models/booking_model.dart';
import '../../../../core/models/trip_model.dart';

class MockPassengerRepository {
  List<TripModel> fetchTrips() {
    final now = DateTime.now();

    return [
      TripModel(
        id: 'trip-001',
        routeName: '大学城早班线',
        origin: '南门学生公寓',
        destination: '综合教学楼',
        vehicleId: 'bus-001',
        driverId: 'driver-001',
        departureTime: now.add(const Duration(hours: 1, minutes: 40)),
        totalSeats: 45,
        bookedSeats: 18,
        fare: 3,
        status: TripStatus.scheduled,
      ),
      TripModel(
        id: 'trip-002',
        routeName: '科技园通勤线',
        origin: '图书馆广场',
        destination: '科技园东门',
        vehicleId: 'bus-002',
        driverId: 'driver-002',
        departureTime: now.add(const Duration(hours: 3, minutes: 15)),
        totalSeats: 38,
        bookedSeats: 29,
        fare: 5,
        status: TripStatus.scheduled,
      ),
      TripModel(
        id: 'trip-003',
        routeName: '晚间返校线',
        origin: '附属医院站',
        destination: '北区宿舍',
        vehicleId: 'bus-003',
        driverId: 'driver-003',
        departureTime: now.add(const Duration(hours: 6, minutes: 20)),
        totalSeats: 32,
        bookedSeats: 12,
        fare: 4,
        status: TripStatus.scheduled,
      ),
      TripModel(
        id: 'trip-004',
        routeName: '校区环线',
        origin: '体育馆',
        destination: '创新中心',
        vehicleId: 'bus-004',
        driverId: 'driver-004',
        departureTime: now.add(const Duration(days: 1, hours: 1)),
        totalSeats: 28,
        bookedSeats: 28,
        fare: 2,
        status: TripStatus.scheduled,
      ),
    ];
  }

  List<BookingModel> fetchBookings() {
    final now = DateTime.now();

    return [
      BookingModel(
        id: 'booking-legacy-001',
        userId: 'u-passenger-001',
        tripId: 'trip-003',
        seatNo: 7,
        status: BookingStatus.completed,
        fare: 4,
        createdAt: now.subtract(const Duration(days: 3, hours: 4)),
        paymentStatus: BookingPaymentStatus.paid,
      ),
      BookingModel(
        id: 'booking-legacy-002',
        userId: 'u-passenger-001',
        tripId: 'trip-002',
        seatNo: 16,
        status: BookingStatus.cancelled,
        fare: 5,
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
        cancelledAt: now.subtract(const Duration(days: 1, hours: 5)),
        creditPenalty: 2,
        paymentStatus: BookingPaymentStatus.refunded,
      ),
    ];
  }
}

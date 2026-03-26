import axios from 'axios';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

const db = admin.firestore();
const bucket = admin.storage().bucket();

interface Booking {
  cameraUsername: string;
  cameraPassword: string;
  cameraIpAddress: string;
  bookingId: string;
  timeSlot: {
    start: string; // ISO String format
    end: string;   // ISO String format
  };
}

export const monitorBookings = async () => {
  const bookingsSnapshot = await db.collection('bookings').get();
  bookingsSnapshot.forEach(async doc => {
    const booking = doc.data() as Booking;
    await handleBooking(booking);
  });
};

const handleBooking = async (booking: Booking) => {
  const { cameraUsername, cameraPassword, cameraIpAddress, bookingId, timeSlot } = booking;
  const startTime = new Date(timeSlot.start);
  const endTime = new Date(timeSlot.end);
  const now = new Date();

  if (now >= startTime && now < endTime) {
    await startRecording(cameraIpAddress, cameraUsername, cameraPassword, startTime, endTime, bookingId);
  }
};

const startRecording = async (ip: string, username: string, password: string, start: Date, end: Date, bookingId: string) => {
  try {
    const loginResponse = await axios.post(`http://${ip}/cgi-bin/api.cgi?cmd=Login&user=${username}&password=${password}`, {});

    if (loginResponse.data && loginResponse.data[0].code === 0) {
      console.log(`Successfully logged in to camera ${ip}`);
      
      const startRecordingResponse = await axios.post(`http://${ip}/cgi-bin/api.cgi?cmd=StartRec&channel=0&stream=main&user=${username}&password=${password}`, {});
      
      if (startRecordingResponse.data && startRecordingResponse.data[0].code === 0) {
        console.log(`Recording started for booking ${bookingId} from ${start} to ${end}`);

        const recordingDuration = end.getTime() - start.getTime();
        await new Promise(resolve => setTimeout(resolve, recordingDuration));

        const stopRecordingResponse = await axios.post(`http://${ip}/cgi-bin/api.cgi?cmd=StopRec&channel=0&stream=main&user=${username}&password=${password}`, {});

        if (stopRecordingResponse.data && stopRecordingResponse.data[0].code === 0) {
          console.log(`Recording stopped for booking ${bookingId}`);
          
          // Upload the recording to Firestore
          await uploadRecordingToFirestore(bookingId);
        } else {
          console.error(`Failed to stop recording for booking ${bookingId}`);
        }
      } else {
        console.error(`Failed to start recording for booking ${bookingId}`);
      }
    } else {
      console.error(`Failed to log in to camera ${ip}`);
    }
  } catch (error) {
    console.error(`Error handling booking ${bookingId}:`, error);
  }
};

const uploadRecordingToFirestore = async (bookingId: string) => {
  const recordingFilePath = path.resolve('./recording.mp4');

  try {
    await bucket.upload(recordingFilePath, {
      destination: `recordings/${bookingId}.mp4`,
      metadata: {
        contentType: 'video/mp4',
      },
    });

    console.log(`Recording uploaded to Firestore for booking ${bookingId}`);

    // Delete the local file after successful upload
    fs.unlink(recordingFilePath, (err) => {
      if (err) {
        console.error(`Failed to delete local recording file: ${err}`);
      } else {
        console.log(`Local recording file deleted successfully.`);
      }
    });
  } catch (error) {
    console.error(`Failed to upload recording for booking ${bookingId}: ${error}`);
  }
};

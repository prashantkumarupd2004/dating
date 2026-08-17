import Razorpay from 'razorpay';
import crypto from 'crypto';
import { config } from '../config';

export const razorpay = new Razorpay({
  key_id: config.razorpay.keyId,
  key_secret: config.razorpay.keySecret,
});

export const createOrder = async (amountInPaise: number, receipt: string) => {
  return razorpay.orders.create({
    amount: amountInPaise,
    currency: 'INR',
    receipt,
  });
};

export const verifyPaymentSignature = (
  orderId: string,
  paymentId: string,
  signature: string
): boolean => {
  const body = `${orderId}|${paymentId}`;
  const expected = crypto
    .createHmac('sha256', config.razorpay.keySecret)
    .update(body)
    .digest('hex');
  return expected === signature;
};

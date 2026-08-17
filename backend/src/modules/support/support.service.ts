import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';

export const createTicket = async (userId: string, subject: string, message: string) => {
  return prisma.supportTicket.create({
    data: {
      userId,
      subject,
      status: 'OPEN',
      replies: {
        create: {
          message,
          isAdmin: false,
        },
      },
    },
    include: { replies: true },
  });
};

export const getTickets = async (userId: string, filters: { page?: number; limit?: number }) => {
  const { page, limit, skip } = getPagination(filters);
  const [tickets, total] = await Promise.all([
    prisma.supportTicket.findMany({
      where: { userId },
      include: {
        replies: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.supportTicket.count({ where: { userId } }),
  ]);
  return { data: tickets, meta: buildMeta(total, page, limit) };
};

export const getTicket = async (ticketId: string, userId: string) => {
  const ticket = await prisma.supportTicket.findFirst({
    where: { id: ticketId, userId },
    include: { replies: { orderBy: { createdAt: 'asc' } } },
  });
  if (!ticket) throw new AppError(404, 'Ticket not found');
  return ticket;
};

export const replyToTicket = async (ticketId: string, userId: string, message: string) => {
  const ticket = await prisma.supportTicket.findFirst({ where: { id: ticketId, userId } });
  if (!ticket) throw new AppError(404, 'Ticket not found');
  if (ticket.status === 'CLOSED') throw new AppError(400, 'Cannot reply to a closed ticket');

  const reply = await prisma.ticketReply.create({
    data: {
      ticketId,
      message,
      isAdmin: false,
    },
  });

  await prisma.supportTicket.update({
    where: { id: ticketId },
    data: { status: 'OPEN' },
  });

  return reply;
};

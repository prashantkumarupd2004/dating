import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';

export const listTickets = async (req: AdminRequest, res: Response): Promise<void> => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = 20;
  const where: any = {};
  if (req.query.status) where.status = req.query.status;

  const [tickets, total] = await Promise.all([
    prisma.supportTicket.findMany({
      where, skip: (page - 1) * limit, take: limit, orderBy: { createdAt: 'desc' },
      include: { user: { select: { name: true } }, replies: { orderBy: { createdAt: 'asc' } } },
    }),
    prisma.supportTicket.count({ where }),
  ]);
  sendSuccess(res, { tickets, total, page, totalPages: Math.ceil(total / limit) });
};

export const replyToTicket = async (req: AdminRequest, res: Response): Promise<void> => {
  const reply = await prisma.ticketReply.create({
    data: { ticketId: req.params.id, message: req.body.message, isAdmin: true },
  });
  if (req.body.status) {
    await prisma.supportTicket.update({ where: { id: req.params.id }, data: { status: req.body.status } });
  }
  sendSuccess(res, reply, 'Reply sent');
};

export const updateTicketStatus = async (req: AdminRequest, res: Response): Promise<void> => {
  const ticket = await prisma.supportTicket.update({
    where: { id: req.params.id }, data: { status: req.body.status },
  });
  sendSuccess(res, ticket);
};

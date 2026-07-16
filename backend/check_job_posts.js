
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkJobs() {
    try {
        const jobs = await prisma.jobPost.findMany({
            include: { customer: true }
        });
        console.log(`Found ${jobs.length} jobs.`);
        jobs.forEach(job => {
            console.log(`Job: ${job.title}, ID: ${job.id}, Category: ${job.category}, Budget: ${job.budget}`);
        });
    } catch (e) {
        console.error(e);
    } finally {
        await prisma.$disconnect();
    }
}

checkJobs();

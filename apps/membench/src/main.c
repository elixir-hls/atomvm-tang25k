/* Memory system microbenchmark: CPU cycles per access for the cases that dominate an
 * interpreter (I/D-cache hits, SDRAM misses, stores through the write-through D-cache). */
#include <string.h>
#include <zephyr/kernel.h>

#define BIG (1024 * 1024)

static uint8_t big[BIG] __aligned(64);
static uint8_t big2[BIG] __aligned(64);

static inline uint32_t cycles(void)
{
	return k_cycle_get_32();
}

static void report(const char *name, uint32_t c, uint32_t n)
{
	printk("%-34s %6u.%02u cycles/op\n", name, c / n, (c % n) * 100 / n);
}

int main(void)
{
	volatile uint32_t *w = (volatile uint32_t *)big;
	uint32_t c, sum = 0;
	const uint32_t n = 65536;

	memset(big, 1, BIG);

	c = cycles();
	for (uint32_t i = 0; i < n; i++) {
		sum += w[i & 511];             /* 2 KB, D-cache hits */
	}
	report("load, 2 KB (D$ hit)", cycles() - c, n);

	c = cycles();
	for (uint32_t i = 0; i < n; i++) {
		sum += w[(i * 8) & (BIG / 4 - 1)];   /* one per 32-byte line: every load misses */
	}
	report("load, new line each (D$ miss)", cycles() - c, n);

	c = cycles();
	for (uint32_t i = 0; i < n; i++) {
		w[i & 511] = i;                /* stores to cached lines */
	}
	report("store, 2 KB (write-through)", cycles() - c, n);

	c = cycles();
	for (uint32_t i = 0; i < n; i++) {
		w[i] = i;                      /* sequential stores, 256 KB */
	}
	report("store, sequential 256 KB", cycles() - c, n);

	c = cycles();
	memcpy(big2, big, 256 * 1024);
	report("memcpy 256 KB, per word", cycles() - c, 256 * 1024 / 4);

	c = cycles();
	memset(big2, 0, 256 * 1024);
	report("memset 256 KB, per word", cycles() - c, 256 * 1024 / 4);

	printk("(sum %u, %u MHz)\n", sum, sys_clock_hw_cycles_per_sec() / 1000000);
	return 0;
}

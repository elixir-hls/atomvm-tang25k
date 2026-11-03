/* S1 check: Zephyr on the imac SoC; the loop exercises atomics (A) and the C build. */
#include <zephyr/kernel.h>
#include <zephyr/sys/atomic.h>

int main(void)
{
	atomic_t n = ATOMIC_INIT(0);

	for (int i = 0; i < 1000; i++) {
		atomic_inc(&n);
	}
	printk("Hello from Zephyr on Tang Primer 25K (%s), atomic count %ld\n",
	       CONFIG_BOARD, (long)atomic_get(&n));
	return 0;
}

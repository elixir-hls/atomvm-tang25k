/*
 * Fills the SDRAM slots AtomVM's main() reads the AVM packs from (docs/design.md section 3),
 * so that BEAM code runs from SDRAM rather than over the 1x SPI flash bus:
 *   library (atomvmlib): copied from the SPI flash;
 *   application: a pack serial-loaded into the staging slot (scripts/load_app.py) is moved
 *     and the staging copy invalidated, so a later reset does not rerun a stale upload;
 *     otherwise the pack in the SPI flash is copied (standalone boot).
 * A missing pack leaves the slot invalid; AtomVM then reports it.
 */
#include <string.h>
#include <zephyr/init.h>
#include <zephyr/sys/byteorder.h>
#include <zephyr/sys/printk.h>

#define AVM_HEADER "#!/usr/bin/env AtomVM\n"
#define AVM_HEADER_SIZE 24
#define AVM_END_SECTION_SIZE 16 /* size 0, flags, reserved, "end\0" */

/* Total size of the pack at p, or 0 if there is no valid pack within max bytes */
static size_t pack_size(const uint8_t *p, size_t max)
{
    if (memcmp(p, AVM_HEADER, sizeof(AVM_HEADER) - 1) != 0) {
        return 0;
    }
    size_t offset = AVM_HEADER_SIZE;
    while (offset + AVM_END_SECTION_SIZE <= max) {
        uint32_t section_size = sys_get_be32(p + offset);
        if (section_size == 0) {
            return offset + AVM_END_SECTION_SIZE;
        }
        if (section_size % 4 != 0 || section_size > max - offset) {
            return 0;
        }
        offset += section_size;
    }
    return 0;
}

/* Copies the pack at src to dst; returns its size, 0 (and dst invalidated) if there is none */
static size_t copy_pack(uint8_t *dst, const uint8_t *src, size_t max)
{
    size_t size = pack_size(src, max);
    if (size > 0) {
        memcpy(dst, src, size);
    } else {
        memset(dst, 0, AVM_HEADER_SIZE);
    }
    return size;
}

static int avm_loader_init(void)
{
    uint8_t *staging = (uint8_t *) CONFIG_TANG_AVM_STAGING_ADDRESS;
    size_t size;

    size = copy_pack((uint8_t *) CONFIG_AVM_LIB_ADDRESS,
        (const uint8_t *) CONFIG_TANG_AVM_FLASH_LIB_ADDRESS, CONFIG_AVM_LIB_SIZE);
    printk("avm_loader: library %u B from SPI flash\n", (unsigned) size);

    size = copy_pack((uint8_t *) CONFIG_AVM_APP_ADDRESS, staging, CONFIG_AVM_APP_SIZE);
    if (size > 0) {
        memset(staging, 0, AVM_HEADER_SIZE);
        printk("avm_loader: application %u B from the serial load\n", (unsigned) size);
        return 0;
    }
    size = copy_pack((uint8_t *) CONFIG_AVM_APP_ADDRESS,
        (const uint8_t *) CONFIG_TANG_AVM_FLASH_APP_ADDRESS, CONFIG_AVM_APP_SIZE);
    printk("avm_loader: application %u B from SPI flash\n", (unsigned) size);
    return 0;
}

SYS_INIT(avm_loader_init, APPLICATION, 0);

fmt:
    @echo "format step not configured yet"

lint:
    @echo "lint step not configured yet"

test:
    @echo "test step not configured yet"

smoke:
    @echo "smoke step not configured yet"

check:
    just fmt
    just lint
    just test

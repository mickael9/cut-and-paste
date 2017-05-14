VERSION=$(shell grep -Po '(?<="version": ")[0-9.]+(?=")' info.json)
NAME=$(shell grep -Po '(?<="name": ")[^"]+(?=")' info.json)

NAME_VER=$(NAME)_$(VERSION)
ZIP=$(NAME_VER).zip

FILES=$(wildcard README.md LICENSE info.json *.lua */)

all: $(ZIP)

$(ZIP): $(FILES)
	@git archive --format=zip --prefix=$(NAME_VER)/ -o $@ HEAD $^

install: $(ZIP)
	@cp $(ZIP) ~/.factorio/mods

link:
	@ln -sf  $(CURDIR) ~/.factorio/mods/$(NAME_VER)

clean:
	@rm -f $(NAME)_*.zip

.PHONY: all clean install link
.PHONY: $(ZIP) # always rebuild

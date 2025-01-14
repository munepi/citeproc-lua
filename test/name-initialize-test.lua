require("busted.runner")()

local name = require("citeproc-node-names").Name


describe("String split", function ()

  local context = {
    ["initialize-with-hyphen"] = true,
    initialize=true,
  }

    describe("Initialize true:", function ()
      context.initialize = true

      describe("Space:", function ()
      it("ME", function ()
        assert.equal("M", name:initialize_name("ME", " ", context))
      end)
      it("M.E", function ()
        assert.equal("M E", name:initialize_name("M.E", " ", context))
      end)
      it("M E.", function ()
        assert.equal("M E", name:initialize_name("M E.", " ", context))
      end)
      it("John M.E.", function ()
        assert.equal("J M E", name:initialize_name("John M.E.", " ", context))
      end)
      it("M E", function ()
        assert.equal("M E", name:initialize_name("M E", " ", context))
      end)
      it("ME.", function ()
        assert.equal("ME", name:initialize_name("ME.", " ", context))
      end)
      it("Me.", function ()
        assert.equal("Me", name:initialize_name("Me.", " ", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph M E", name:initialize_name("Ph.M.E.", " ", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph M E", name:initialize_name("Ph. M.E.", " ", context))
      end)
    end)

      describe("Empty:", function ()
      it("ME", function ()
        assert.equal("M", name:initialize_name("ME", "", context))
      end)
      it("M.E", function ()
        assert.equal("ME", name:initialize_name("M.E", "", context))
      end)
      it("M E.", function ()
        assert.equal("ME", name:initialize_name("M E.", "", context))
      end)
      it("John M.E.", function ()
        assert.equal("JME", name:initialize_name("John M.E.", "", context))
      end)
      it("M E", function ()
        assert.equal("ME", name:initialize_name("M E", "", context))
      end)
      it("ME.", function ()
        assert.equal("ME", name:initialize_name("ME.", "", context))
      end)
      it("Me.", function ()
        assert.equal("Me", name:initialize_name("Me.", "", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("PhME", name:initialize_name("Ph.M.E.", "", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("PhME", name:initialize_name("Ph. M.E.", "", context))
      end)
    end)

      describe("Period:", function ()
      it("ME", function ()
        assert.equal("M.", name:initialize_name("ME", ".", context))
      end)
      it("M.E", function ()
        assert.equal("M.E.", name:initialize_name("M.E", ".", context))
      end)
      it("M E.", function ()
        assert.equal("M.E.", name:initialize_name("M E.", ".", context))
      end)
      it("John M.E.", function ()
        assert.equal("J.M.E.", name:initialize_name("John M.E.", ".", context))
      end)
      it("M E", function ()
        assert.equal("M.E.", name:initialize_name("M E", ".", context))
      end)
      it("ME.", function ()
        assert.equal("ME.", name:initialize_name("ME.", ".", context))
      end)
      it("Me.", function ()
        assert.equal("Me.", name:initialize_name("Me.", ".", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph.M.E.", name:initialize_name("Ph.M.E.", ".", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph.M.E.", name:initialize_name("Ph. M.E.", ".", context))
      end)
    end)

      describe("PeriodSpace:", function ()
      it("ME", function ()
        assert.equal("M.", name:initialize_name("ME", ". ", context))
      end)
      it("M.E", function ()
        assert.equal("M. E.", name:initialize_name("M.E", ". ", context))
      end)
      it("M E.", function ()
        assert.equal("M. E.", name:initialize_name("M E.", ". ", context))
      end)
      it("John M.E.", function ()
        assert.equal("J. M. E.", name:initialize_name("John M.E.", ". ", context))
      end)
      it("M E", function ()
        assert.equal("M. E.", name:initialize_name("M E", ". ", context))
      end)
      it("ME.", function ()
        assert.equal("ME.", name:initialize_name("ME.", ". ", context))
      end)
      it("Me.", function ()
        assert.equal("Me.", name:initialize_name("Me.", ". ", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph. M. E.", name:initialize_name("Ph.M.E.", ". ", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph. M. E.", name:initialize_name("Ph. M.E.", ". ", context))
      end)
    end)

  end)

    describe("Initialize false:", function ()
      context.initialize = false

      describe("Space:", function ()
      it("ME", function ()
        assert.equal("ME", name:initialize_name("ME", " ", context))
      end)
      it("M.E", function ()
        assert.equal("M E", name:initialize_name("M.E", " ", context))
      end)
      it("M E.", function ()
        assert.equal("M E", name:initialize_name("M E.", " ", context))
      end)
      it("John M.E.", function ()
        assert.equal("John M E", name:initialize_name("John M.E.", " ", context))
      end)
      it("M E", function ()
        assert.equal("M E", name:initialize_name("M E", " ", context))
      end)
      it("ME.", function ()
        assert.equal("ME", name:initialize_name("ME.", " ", context))
      end)
      it("Me.", function ()
        assert.equal("Me", name:initialize_name("Me.", " ", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph M E", name:initialize_name("Ph.M.E.", " ", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph M E", name:initialize_name("Ph. M.E.", " ", context))
      end)
    end)

      describe("Empty:", function ()
      it("ME", function ()
        assert.equal("ME", name:initialize_name("ME", "", context))
      end)
      it("M.E", function ()
        assert.equal("ME", name:initialize_name("M.E", "", context))
      end)
      it("M E.", function ()
        assert.equal("ME", name:initialize_name("M E.", "", context))
      end)
      it("John M.E.", function ()
        assert.equal("John ME", name:initialize_name("John M.E.", "", context))
      end)
      it("M E", function ()
        assert.equal("ME", name:initialize_name("M E", "", context))
      end)
      it("ME.", function ()
        assert.equal("ME", name:initialize_name("ME.", "", context))
      end)
      it("Me.", function ()
        assert.equal("Me", name:initialize_name("Me.", "", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("PhME", name:initialize_name("Ph.M.E.", "", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("PhME", name:initialize_name("Ph. M.E.", "", context))
      end)
    end)

      describe("Period:", function ()
      it("ME", function ()
        assert.equal("ME", name:initialize_name("ME", ".", context))
      end)
      it("M.E", function ()
        assert.equal("M.E.", name:initialize_name("M.E", ".", context))
      end)
      it("M E.", function ()
        assert.equal("M.E.", name:initialize_name("M E.", ".", context))
      end)
      it("John M.E.", function ()
        assert.equal("John M.E.", name:initialize_name("John M.E.", ".", context))
      end)
      it("M E", function ()
        assert.equal("M.E.", name:initialize_name("M E", ".", context))
      end)
      it("ME.", function ()
        assert.equal("ME.", name:initialize_name("ME.", ".", context))
      end)
      it("Me.", function ()
        assert.equal("Me.", name:initialize_name("Me.", ".", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph.M.E.", name:initialize_name("Ph.M.E.", ".", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph.M.E.", name:initialize_name("Ph. M.E.", ".", context))
      end)
    end)

      describe("PeriodSpace:", function ()
      it("ME", function ()
        assert.equal("ME", name:initialize_name("ME", ". ", context))
      end)
      it("M.E", function ()
        assert.equal("M. E.", name:initialize_name("M.E", ". ", context))
      end)
      it("M E.", function ()
        assert.equal("M. E.", name:initialize_name("M E.", ". ", context))
      end)
      it("John M.E.", function ()
        assert.equal("John M. E.", name:initialize_name("John M.E.", ". ", context))
      end)
      it("M E", function ()
        assert.equal("M. E.", name:initialize_name("M E", ". ", context))
      end)
      it("ME.", function ()
        assert.equal("ME.", name:initialize_name("ME.", ". ", context))
      end)
      it("Me.", function ()
        assert.equal("Me.", name:initialize_name("Me.", ". ", context))
      end)
      it("Ph.M.E.", function ()
        assert.equal("Ph. M. E.", name:initialize_name("Ph.M.E.", ". ", context))
      end)
      it("Ph. M.E.", function ()
        assert.equal("Ph. M. E.", name:initialize_name("Ph. M.E.", ". ", context))
      end)
    end)

  end)

  -- describe("initialize-with-hyphen = false", function ()
  --   context.options["initialize-with-hyphen"] = false
  --   context.initialize = true
  --   it("initialize", function ()
  --     assert.equal("J.L.", name:initialize_name("Jean-Luc", ".", context))
  --   end)
  -- end)

end)
